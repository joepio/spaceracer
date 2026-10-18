"""Tune SpaceRacer's sound recipes with the AI judge (hill climbing).

    python tools/audio_search.py boost rail warp --steps 40

For each named recipe in tools/render_racer_audio.py: mutate a few of its
numbers, render, score with tools/audio_judge.py (CLAP match against the
clip's description, minus AudioSet "bad" tags such as hiss, wind or
vacuum cleaner), and keep the change when the score improves. Improvements
are written to tools/audio_params.json; run render_racer_audio.py after.
Engine loops are scored at a low and a high pitch, as the game plays them.
"""
import argparse, json, sys
from pathlib import Path
import numpy as np, librosa
sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_racer_audio as R
from audio_judge import Judge, CLIPS, UNWANTED

PITCHED = {"drive": (.9, 1.3), "idle": (.9, 1.2), "boost_loop": (1., 1.12), "air": (1., 1.1)}
EXTRA_BAD = ["an electric toothbrush", "mains hum", "a buzzing insect", "a car alarm", "a phone ringtone"]

def score(judge, name, p):
    try: return _score(judge, name, p)
    except (ValueError, ZeroDivisionError, librosa.util.exceptions.ParameterError): return -1.

def _score(judge, name, p):
    total = []
    for variant in (0, 2):
        x = R.render(name, p, variant)
        if len(x) < R.SR * .05 or not np.isfinite(x).all(): return -1.
        for pitch in PITCHED.get(name, (1.,)):
            y = librosa.resample(x, orig_sr=R.SR * pitch, target_sr=48000)
            _, good, bad = judge.tags(librosa.resample(y, orig_sr=48000, target_sr=16000))
            total.append(judge.wanted(judge.audio_embed(y), CLIPS[name], UNWANTED + EXTRA_BAD) - .5 * bad + .1 * min(good, 1.))
        if name not in R.ONE_SHOTS: break
    return float(np.mean(total))

# Keep the search musical: without these it drifts to sub-bass rumbles and
# shrill beeps that a classifier likes but a player would not.
LIMITS = {"drive": {"f0": (35, 140), "roll": (.4, 1.5), "vib": (0, 8)}, "idle": {"f0": (35, 120)},
          "boost_loop": {"up": (1., 2.)}, "air": {"bright": (0, 3), "gust": (0, .5), "lo": (100, 2000)},
          "*": {"pitch": (.5, 2.), "length": (.4, 1.4), "open": (.05, 1.), "curve": (.2, 3.), "detune": (0, .02),
                "decay": (.8, 30.), "fall": (.3, 30.), "echo": (0, .7)}}

def clamp(name, p):
    q = dict(p)
    for key, (lo, hi) in {**LIMITS["*"], **LIMITS.get(name, {})}.items():
        if key in q: q[key] = round(float(np.clip(q[key], lo, hi)), 4)
    for key, v in q.items():
        if isinstance(v, float) and key not in ("arp", "odd"): q[key] = min(v, 4.) if not (key.endswith("hz") or key in ("f0", "f1", "f2", "lo", "hi", "nlo", "nhi", "bright", "cutoff")) else v
    return q

def mutate(p, rng, count=3):
    q = dict(p)
    for key in rng.choice(list(p), min(count, len(p)), replace=False):
        v = float(q[key])
        if key.endswith("hz") or key in ("f0", "f1", "f2", "lo", "hi", "nlo", "nhi", "bright", "cutoff"):
            v = float(np.clip(v * np.exp(rng.normal() * .3), 20., 18000.))
        elif key in ("arp", "odd"): continue
        else: v = max(0., v * np.exp(rng.normal() * .4) + rng.normal() * .08)
        q[key] = round(v, 4)
    return q

def mutated(name, p, rng): return clamp(name, mutate(p, rng))

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="+"); ap.add_argument("--steps", type=int, default=40); ap.add_argument("--seed", type=int, default=1)
    a = ap.parse_args()
    judge = Judge(); rng = np.random.default_rng(a.seed)
    for name in a.names:
        best = clamp(name, R.params()[name]); best_score = score(judge, name, best)
        print(f"{name}: start {best_score:.3f}", flush=True)
        for step in range(a.steps):
            cand = mutated(name, best, rng)
            s = score(judge, name, cand)
            if s > best_score:
                best, best_score = cand, s
                tuned = json.loads(R.PARAMS.read_text()) if R.PARAMS.exists() else {}
                tuned[name] = best; R.PARAMS.write_text(json.dumps(tuned, indent=1, sort_keys=True) + "\n")
                print(f"{name}: step {step} {best_score:.3f}", flush=True)
        print(f"{name}: best {best_score:.3f} {json.dumps(best)}", flush=True)

if __name__ == "__main__":
    main()
