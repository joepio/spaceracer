"""Engine sound lab: layered engine designs rendered as one drive.

    python3 tools/engine_lab.py OUT_DIR [--kenney DIR]

Each design is a stack of looping layers. Every layer has its own pitch
curve (most follow road speed, some follow revs) and gain curve (some are
always there, some only swell near the top of the rev range or on boost).
The lab drives every design through the same 14 s timeline: idle on the
grid, launch, full throttle up to top speed, cruise, boost, boost ends,
throttle lift. The game mixes layers the same way (src/engine_audio.gd), so
the winning design can be ported layer for layer.

--kenney points at an unpacked Kenney "Sci-Fi Sounds" pack (CC0,
https://kenney.nl/assets/sci-fi-sounds); designs that need it are skipped
without it.
"""
import argparse, json, sys
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_racer_audio as R
SR = R.SR

# --- Drive timeline -------------------------------------------------------
def timeline():
    dt = 1 / SR; n = int(14 * SR); t = np.arange(n) * dt
    power = np.where(t < 1.6, 0., 1.)                 # throttle from the launch
    power = np.where((t >= 12.) , 0., power)          # lift off at the end
    speed = np.zeros(n); boost = np.zeros(n); v = 0.
    for i, s in enumerate(t):
        b = 1. if 8. <= s < 10.5 else 0.
        top = 1.32 if b else 1.
        accel = (.55 * power[i] * (1.15 - v) if v < top else -.35 * (v - top)) + 1.4 * b * max(0, top - v)
        if power[i] == 0: accel = -.12 * v
        v = max(0., v + accel * dt); speed[i] = v; boost[i] = b
    boost = R.lowpass(boost, 6.)                     # level smoothing like the game
    spool = np.clip(power * .58 + np.minimum(speed, 1) * .42, 0, 1)
    rpm = R.lowpass(np.where(t < .9, .02, spool) + .25 * boost, 2.5)  # clutch-free hover spool
    return dict(t=t, power=power, speed=speed, boost=boost, rpm=rpm)

# --- Layer playback -------------------------------------------------------
def play(loop, rate, gain):
    """Loop `loop` at a time-varying playback rate, scaled by `gain`."""
    pos = np.cumsum(np.broadcast_to(rate, gain.shape)) % len(loop)
    i = pos.astype(int); f = pos - i
    return (loop[i] * (1 - f) + loop[(i + 1) % len(loop)] * f) * gain

def smooth(x, lo, hi): u = np.clip((x - lo) / (hi - lo), 0, 1); return u * u * (3 - 2 * u)

# --- Loop sources ---------------------------------------------------------
L = 4.; N = int(L * SR); T = np.arange(N) / SR
G = lambda f: R.on_grid(f, L)
def rng(k): return np.random.default_rng(4100 + k)

def harmonic(f0, roll=1., formants=(), top=12000, k_rng=0, vib=0., vib_hz=5.):
    k = np.arange(1, int(top / f0) + 1); amps = 1 / k ** roll
    for fc, g, w in formants: amps = amps * (1 + g * np.exp(-((f0 * k - fc) / (fc * w)) ** 2))
    r = rng(k_rng); x = np.zeros(N)
    for kk, a in zip(k, amps):
        ph = r.uniform(0, 2 * np.pi)
        x += a * np.sin(2 * np.pi * G(f0 * kk) * T + ph + vib * kk ** .5 * np.sin(2 * np.pi * G(vib_hz) * T))
    return R.norm(x)

def whine(freqs, fm=0., fm_hz=7., k_rng=1):
    r = rng(k_rng); x = np.zeros(N)
    for f, a in freqs:
        x += a * np.sin(2 * np.pi * G(f) * T + r.uniform(0, 6.3) + fm * np.sin(2 * np.pi * G(fm_hz) * T))
    return R.norm(x)

def noise(lo, hi, k_rng=2, flange=0.):
    x = R.band(rng(k_rng).normal(size=N), lo, hi)
    if flange: x = R.comb(x, .003 + .002 * np.sin(2 * np.pi * G(.5) * T), flange)
    return R.norm(x)

def sample_loop(path, start=.3, length=3.5):
    x = R.decode(Path(path).read_bytes())
    a = int(start * SR); b = min(len(x), a + int(length * SR))
    return R.norm(R.seam(x[a:b], .25))

def jet(start=20, length=L + .25):
    x = R.Sources.jet(); return R.norm(R.seam(R.band(x[int(start * SR): int((start + length) * SR)], 60, 14000), .25))

def tremolo(x, depth, hz): return x * (1 + depth * np.sin(2 * np.pi * G(hz) * T))

# --- Designs --------------------------------------------------------------
# Each layer: (name, loop, pitch(ctx), gain(ctx)). ctx has speed, rpm, boost, power.
def designs(kenney):
    k = (lambda name: sample_loop(Path(kenney) / f'{name}.ogg')) if kenney else None
    D = {}
    D['A_turbine'] = dict(about='Synth turbine: low hover hum on speed, a turbine whine on revs, a high scream only near the top, noise roar on boost.', layers=[
        ('hover hum', tremolo(harmonic(55, 1.3, [(220, 1.5, .5)], 3000, 3), .25, 6.), lambda c: .8 + .5 * c['speed'], lambda c: .55 - .15 * c['speed']),
        ('turbine', harmonic(110, .9, [(900, 2.5, .35), (2400, 1.2, .25)], 9000, 4, .02, 6.), lambda c: .55 + .9 * c['rpm'], lambda c: .15 + .6 * c['rpm'] ** 1.5),
        ('scream', whine([(1840, 1.), (2760, .5), (3680, .3), (5520, .12)], 1.2, 9.), lambda c: .62 + .55 * c['rpm'], lambda c: .5 * smooth(c['rpm'], .62, 1.05) ** 2),
        ('air', noise(400, 12000, 5), lambda c: 1. + .2 * c['speed'], lambda c: .18 * c['speed'] ** 2),
        ('boost roar', noise(70, 9000, 6, .8), lambda c: .9 + .2 * c['boost'], lambda c: .75 * c['boost']),
    ])
    D['B_jet'] = dict(about='Recorded jet (Freesound CC0) as the body on speed, synth sub pulse that quickens with speed, turbine whine that opens up at high revs, flanged afterburner on boost.', layers=[
        ('jet body', jet(20), lambda c: .7 + .45 * c['speed'], lambda c: .2 + .5 * c['rpm']),
        ('sub pulse', tremolo(harmonic(41, 1.6, [], 400, 7), .6, 10.), lambda c: .85 + .45 * c['speed'], lambda c: .5 - .1 * c['speed']),
        ('whine', harmonic(330, 1.1, [(2000, 2., .3)], 12000, 8), lambda c: .55 + .7 * c['rpm'], lambda c: .45 * smooth(c['rpm'], .5, 1.) ** 1.5),
        ('afterburner', R.norm(R.comb(jet(31), .004 + .002 * np.sin(2 * np.pi * G(.5) * T), .8)), lambda c: 1.1 + .15 * c['boost'], lambda c: .8 * c['boost']),
    ])
    if k:
        D['C_kenney'] = dict(about='Kenney CC0 space engines stacked: large engine as the low body on speed, regular engine on revs, small engine as a top-end whine, thruster fire on boost.', layers=[
            ('large engine', k('spaceEngineLarge_000'), lambda c: .75 + .4 * c['speed'], lambda c: .55 - .1 * c['speed']),
            ('engine', k('spaceEngine_000'), lambda c: .6 + .8 * c['rpm'], lambda c: .15 + .5 * c['rpm'] ** 1.5),
            ('small engine', k('spaceEngineSmall_000'), lambda c: .7 + .6 * c['rpm'], lambda c: .55 * smooth(c['rpm'], .6, 1.05) ** 2),
            ('thruster', k('thrusterFire_000'), lambda c: .95 + .15 * c['boost'], lambda c: .85 * c['boost']),
        ])
        D['D_hybrid'] = dict(about='Hybrid: Kenney low engine plus synth hover hum as the body, synth turbine on revs, Kenney small engine scream only at the top, Kenney circular engine swirl plus thruster on boost.', layers=[
            ('low engine', k('spaceEngineLow_000'), lambda c: .8 + .35 * c['speed'], lambda c: .45),
            ('hover hum', tremolo(harmonic(55, 1.3, [(220, 1.5, .5)], 3000, 3), .2, 6.), lambda c: .8 + .5 * c['speed'], lambda c: .35 - .1 * c['speed']),
            ('turbine', harmonic(110, .9, [(900, 2.5, .35), (2400, 1.2, .25)], 9000, 4, .02, 6.), lambda c: .55 + .9 * c['rpm'], lambda c: .1 + .45 * c['rpm'] ** 1.5),
            ('scream', k('spaceEngineSmall_000'), lambda c: .75 + .55 * c['rpm'], lambda c: .5 * smooth(c['rpm'], .65, 1.05) ** 2),
            ('swirl', k('engineCircular_000'), lambda c: .9 + .3 * c['boost'], lambda c: .5 * c['boost']),
            ('thruster', k('thrusterFire_000'), lambda c: 1.0, lambda c: .6 * c['boost']),
        ])
    return D

def render(design, ctx):
    stems = {}
    for name, loop, pitch, gain in design['layers']:
        stems[name] = play(loop, pitch(ctx), np.broadcast_to(gain(ctx), ctx['t'].shape).astype(float))
    mix = sum(stems.values())
    return mix * (.8 / max(1e-9, np.max(np.abs(mix)))), stems

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('out'); ap.add_argument('--kenney'); ap.add_argument('--only', nargs='*')
    a = ap.parse_args(); out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    ctx = timeline(); info = {}
    for name, d in designs(a.kenney).items():
        if a.only and name not in a.only: continue
        mix, stems = render(d, ctx)
        with __import__('wave').open(str(out / f'{name}.wav'), 'wb') as w:
            w.setparams((1, 2, SR, 0, 'NONE', 'not compressed')); w.writeframes((mix * 32767).astype('<i2').tobytes())
        info[name] = dict(about=d['about'], layers=[l[0] for l in d['layers']],
                          rms={k: float(np.sqrt(np.mean(v * v))) for k, v in stems.items()})
        print(name, 'ok', flush=True)
    (out / 'designs.json').write_text(json.dumps(info, indent=1))

if __name__ == '__main__':
    main()
