"""Score a recorded SpaceRacer audio scenario with audio AI models and mix metrics.

    python tools/audio_judge.py build/audio-loop/run.wav [--reference fzgx.wav] [--out build/audio-loop/report]

Needs a Python with torch, transformers, librosa, soundfile, pyloudnorm and
matplotlib (see tools/audio_loop.md). Models download from Hugging Face once:
- CLAP (laion/larger_clap_general): how well each moment matches a text
  description of what it should sound like, against "bad" descriptions.
- AST (MIT/ast-finetuned-audioset-10-10-0.4593): AudioSet labels, to catch
  sounds that read as hiss, wind, water or a household appliance.
Mix metrics are loudness (LUFS), peaks and spectral balance per moment.
The run's .json (written by tools/audio_scenario.gd) marks the moments.
Writes <out>.json, <out>.md and <out>.png (spectrogram with markers).
"""
import argparse, json, os, warnings
from pathlib import Path
import numpy as np
warnings.filterwarnings("ignore")
os.environ.setdefault("TRANSFORMERS_VERBOSITY", "error")
import librosa, soundfile as sf, pyloudnorm, torch
from transformers import ClapModel, ClapProcessor, ASTForAudioClassification, ASTFeatureExtractor

# What each moment should sound like. The score is the chance CLAP picks this
# description over the shared "bad" ones below, for that stretch of audio.
WANTED = {
    "countdown": "a race start countdown with beeps and an idling futuristic engine",
    "rev": "a futuristic hover racer engine revving up before the start",
    "launch": "a powerful futuristic anti-gravity racing ship accelerating hard, jet engine roaring",
    "boost": "a sci-fi rocket boost blast with a powerful whoosh",
    "cruise": "a futuristic racing ship engine screaming at very high speed",
    "brake": "a fast spaceship braking hard with air brakes",
    "coast": "a fast futuristic racer gliding with wind rushing past",
    "missile": "a missile launching with a rocket hiss and then exploding",
    "railgun": "a sci-fi laser cannon firing a powerful energy blast",
    "sentry": "a rapid fire sci-fi laser machine gun",
    "emp": "an electromagnetic pulse blast with electric crackle",
    "warp": "a sci-fi warp drive charging and jumping forward",
    "bomb": "a bomb falling and exploding",
    "end": "a futuristic racing ship engine screaming at very high speed",
}
UNWANTED = ["white noise hiss", "wind and rain", "a vacuum cleaner", "a hair dryer",
            "a quiet room with faint hum", "a cheap toy sound effect", "harsh distorted noise"]
# Single sound files, judged on their own (assets/audio/racer/<name>_<n>.wav).
CLIPS = {"boost": WANTED["boost"], "launch": "a missile launching with a powerful rocket ignition",
         "explosion": "a big punchy sci-fi explosion", "rail": WANTED["railgun"], "sentry": WANTED["sentry"],
         "emp": WANTED["emp"], "warp": WANTED["warp"], "drive": "a futuristic anti-gravity racing ship engine roaring at very high speed, jet turbine scream",
         "boost_loop": "a roaring rocket thruster at full boost", "idle": "a futuristic hover ship engine idling",
         "air": "fast wind rushing past a racing ship", "tick": "a futuristic race countdown beep",
         "go": "a futuristic race start signal", "lap": "a video game lap completed chime",
         "pickup": "a video game item pickup sound", "contact": "two metal racing ships scraping and bumping",
         "land": "a heavy hover ship landing with a thud", "warning": "a missile lock-on warning alarm"}
MIX_GOOD = "an exciting high-energy futuristic racing video game with punchy engine and weapon sounds"
MIX_BAD = ["a dull muffled noisy recording", "static and hiss", "a boring quiet hum"]
AST_GOOD = ["Vehicle", "Engine", "Jet engine", "Aircraft", "Race car, auto racing",
            "Accelerating, revving, vroom", "Explosion", "Gunshot, gunfire", "Whoosh, swoosh, swish",
            "Boom", "Machine gun", "Beep, bleep", "Zing", "Burst, pop"]
AST_BAD = ["White noise", "Pink noise", "Static", "Hiss", "Wind", "Rain", "Rustle", "Water",
           "Ocean", "Waterfall", "Steam", "Hum", "Buzz", "Vacuum cleaner", "Hair dryer",
           "Mechanical fan", "Air conditioning", "Noise"]
BANDS = [(20, 80), (80, 250), (250, 1000), (1000, 4000), (4000, 10000), (10000, 20000)]

def features(output):
    # transformers 5 wraps projected features in an output object.
    return output if torch.is_tensor(output) else output.pooler_output

class Judge:
    def __init__(self):
        torch.set_num_threads(max(1, os.cpu_count() or 1))
        self.clap = ClapModel.from_pretrained("laion/larger_clap_general").eval()
        self.clap_in = ClapProcessor.from_pretrained("laion/larger_clap_general")
        self.ast = ASTForAudioClassification.from_pretrained("MIT/ast-finetuned-audioset-10-10-0.4593").eval()
        self.ast_in = ASTFeatureExtractor.from_pretrained("MIT/ast-finetuned-audioset-10-10-0.4593")
        self.labels = self.ast.config.id2label
        self._text = {}

    def text(self, prompts):
        key = tuple(prompts)
        if key not in self._text:
            with torch.no_grad():
                t = self.clap_in(text=list(prompts), return_tensors="pt", padding=True)
                self._text[key] = torch.nn.functional.normalize(features(self.clap.get_text_features(**t)), dim=-1)
        return self._text[key]

    def audio_embed(self, y48):
        with torch.no_grad():
            a = self.clap_in(audio=[y48], sampling_rate=48000, return_tensors="pt")
            return torch.nn.functional.normalize(features(self.clap.get_audio_features(**a)), dim=-1)[0]

    def wanted(self, embedding, good, bad):
        logits = (self.text([good] + bad) @ embedding) * self.clap.logit_scale_a.exp()
        return float(torch.softmax(logits, 0)[0])

    def tags(self, y16):
        with torch.no_grad():
            x = self.ast_in(y16, sampling_rate=16000, return_tensors="pt")
            p = torch.sigmoid(self.ast(**x).logits[0]).numpy()
        named = {self.labels[i]: float(p[i]) for i in range(len(p))}
        top = sorted(named.items(), key=lambda kv: -kv[1])[:5]
        good = sum(named.get(l, 0.) for l in AST_GOOD)
        bad = sum(named.get(l, 0.) for l in AST_BAD)
        return top, good, bad

def mono(path):
    y, sr = sf.read(path, always_2d=True)
    return y.mean(axis=1), sr

def metrics(y, sr, meter):
    peak = 20 * np.log10(max(1e-9, np.abs(y).max()))
    lufs = meter.integrated_loudness(y) if len(y) > sr * .45 else float("nan")
    spec = np.abs(np.fft.rfft(y * np.hanning(len(y)))) ** 2
    f = np.fft.rfftfreq(len(y), 1 / sr)
    total = spec.sum() + 1e-12
    bands = [float(10 * np.log10(spec[(f >= lo) & (f < hi)].sum() / total + 1e-12)) for lo, hi in BANDS]
    centroid = float((f * spec).sum() / total)
    return {"lufs": round(float(lufs), 1), "peak_db": round(float(peak), 1),
            "centroid_hz": round(centroid), "band_db": [round(b, 1) for b in bands]}

def judge(run, reference=None, out=None):
    run = Path(run)
    marks = json.loads(run.with_suffix(".json").read_text())
    y, sr = mono(run)
    meter = pyloudnorm.Meter(sr)
    model = Judge()
    y48 = librosa.resample(y, orig_sr=sr, target_sr=48000)
    y16 = librosa.resample(y, orig_sr=sr, target_sr=16000)
    moments = [e for e in marks["events"] if not e["label"].startswith("fired_")]
    rows = []
    for i, e in enumerate(moments):
        start = e["t"]; end = moments[i + 1]["t"] if i + 1 < len(moments) else len(y) / sr
        if end - start < .4: continue
        cut = lambda z, rate: z[int(start * rate):int(end * rate)]
        emb = model.audio_embed(cut(y48, 48000))
        top, good, bad = model.tags(cut(y16, 16000))
        row = {"label": e["label"], "start": start, "end": round(end, 2),
               "clap_wanted": round(model.wanted(emb, WANTED.get(e["label"], WANTED["cruise"]), UNWANTED), 3),
               "ast_good": round(good, 3), "ast_bad": round(bad, 3),
               "ast_top": [[l, round(p, 3)] for l, p in top]}
        row.update(metrics(cut(y, sr), sr, meter))
        rows.append(row)
    whole = model.audio_embed(y48)
    summary = {"audio_version": marks.get("audio_version"), "seconds": round(len(y) / sr, 1),
               "lufs": round(float(meter.integrated_loudness(y)), 1),
               "peak_db": round(float(20 * np.log10(np.abs(y).max() + 1e-9)), 1),
               "mix_exciting": round(model.wanted(whole, MIX_GOOD, MIX_BAD), 3),
               "clap_wanted_mean": round(float(np.mean([r["clap_wanted"] for r in rows])), 3),
               "ast_bad_mean": round(float(np.mean([r["ast_bad"] for r in rows])), 3)}
    bed = [r["lufs"] for r in rows if r["label"] in ("cruise", "launch", "end") and np.isfinite(r["lufs"])]
    if bed:
        summary["cue_over_bed_db"] = {r["label"]: round(r["lufs"] - float(np.mean(bed)), 1)
                                      for r in rows if r["label"] not in ("cruise", "launch", "end") and np.isfinite(r["lufs"])}
    if reference:
        ref, rsr = mono(reference)
        ref48 = librosa.resample(ref, orig_sr=rsr, target_sr=48000)
        sims = [float(whole @ model.audio_embed(ref48[s:s + 48000 * 10])) for s in range(0, max(1, len(ref48) - 48000 * 10), 48000 * 10)]
        rm = metrics(ref[:rsr * 60], rsr, pyloudnorm.Meter(rsr))
        summary["reference"] = {"file": Path(reference).name, "clap_similarity": round(float(np.mean(sims)), 3),
                                "lufs": rm["lufs"], "band_db": rm["band_db"], "centroid_hz": rm["centroid_hz"],
                                "ours_band_db": metrics(y, sr, meter)["band_db"]}
    report = {"summary": summary, "moments": rows}
    out = Path(out) if out else run.with_name(run.stem + "-report")
    out.with_suffix(".json").write_text(json.dumps(report, indent=1))
    out.with_suffix(".md").write_text(markdown(report))
    spectrogram(y, sr, marks["events"], out.with_suffix(".png"))
    return report

def judge_clips(folder, model=None):
    model = model or Judge(); rows = []
    for path in sorted(Path(folder).glob("*.wav")):
        name = path.stem.rsplit("_", 1)[0] if path.stem.rsplit("_", 1)[-1].isdigit() else path.stem
        if name not in CLIPS or (path.stem[-1].isdigit() and not path.stem.endswith("_1")): continue
        y, sr = mono(path)
        emb = model.audio_embed(librosa.resample(y, orig_sr=sr, target_sr=48000))
        _, good, bad = model.tags(librosa.resample(y, orig_sr=sr, target_sr=16000))
        rows.append({"clip": name, "match": round(model.wanted(emb, CLIPS[name], UNWANTED), 3), "ast_bad": round(bad, 3)})
    return rows

def markdown(report):
    s = report["summary"]
    lines = [f"# Audio judge: {s['audio_version']}", "",
             f"Mix {s['lufs']} LUFS, peak {s['peak_db']} dB. Exciting-mix score {s['mix_exciting']}, "
             f"mean match {s['clap_wanted_mean']}, mean bad-tag {s['ast_bad_mean']}.", "",
             "| moment | match | bad tags | LUFS | top AudioSet tags |", "|---|---|---|---|---|"]
    for r in report["moments"]:
        tags = ", ".join(f"{l} {p:.2f}" for l, p in r["ast_top"][:3])
        lines.append(f"| {r['label']} | {r['clap_wanted']:.2f} | {r['ast_bad']:.2f} | {r['lufs']} | {tags} |")
    if "reference" in s:
        ref = s["reference"]
        lines += ["", f"Reference {ref['file']}: CLAP similarity {ref['clap_similarity']}, {ref['lufs']} LUFS.",
                  f"Band balance (dB share, 20-80/80-250/250-1k/1k-4k/4k-10k/10k+): ours {ref['ours_band_db']}, reference {ref['band_db']}."]
    return "\n".join(lines) + "\n"

def spectrogram(y, sr, events, path):
    import matplotlib; matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    s = librosa.amplitude_to_db(np.abs(librosa.stft(y, n_fft=2048, hop_length=512)), ref=np.max)
    fig, ax = plt.subplots(figsize=(16, 5), dpi=90)
    librosa.display.specshow(s, sr=sr, hop_length=512, x_axis="time", y_axis="log", ax=ax, vmin=-80, vmax=0, cmap="magma")
    for e in events:
        ax.axvline(e["t"], color="cyan" if not e["label"].startswith("fired") else "lime", lw=.8)
        ax.text(e["t"] + .1, 14000 if not e["label"].startswith("fired") else 6000, e["label"].replace("fired_", "*"), color="white", fontsize=8)
    fig.tight_layout(); fig.savefig(path); plt.close(fig)

if __name__ == "__main__":
    import librosa.display  # noqa: F401  (registers specshow)
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("run", help="scenario .wav, or a folder of clips with --clips")
    parser.add_argument("--reference"); parser.add_argument("--out")
    parser.add_argument("--clips", action="store_true", help="score each sound file in the folder on its own")
    a = parser.parse_args()
    if a.clips:
        for r in judge_clips(a.run): print(f"{r['clip']:12} match {r['match']:.2f}  bad tags {r['ast_bad']:.2f}")
    else: print(markdown(judge(a.run, a.reference, a.out)))
