"""Ask a listening model what it hears: written critique of sound files.

    ~/aj/bin/python tools/audio_critic.py build/engine-lab/r1/*.wav

Uses Qwen2.5-Omni-3B (audio-in, text-out; runs on CPU, ~10 GB RAM). Scores
from CLAP and AudioSet (tools/audio_judge.py) say how much a sound matches a
label; this says in words what sounds cheap, thin, harsh or muddy, which is
what a sound designer needs to fix next. Still a guide: a person decides.
"""
import argparse, json, sys
from pathlib import Path
import librosa, torch
from transformers import Qwen2_5OmniThinkerForConditionalGeneration, Qwen2_5OmniProcessor

MODEL = "Qwen/Qwen2.5-Omni-3B"
PROMPT = ("Listen carefully and describe this sound in detail: what does it sound like, what could make this sound, "
          "how does it change over time, and how would you rate its production quality from 1 to 10? Be honest and specific.")

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+"); ap.add_argument("--prompt", default=PROMPT); ap.add_argument("--out")
    a = ap.parse_args()
    torch.set_num_threads(max(1, torch.get_num_threads()))
    processor = Qwen2_5OmniProcessor.from_pretrained(MODEL)
    model = Qwen2_5OmniThinkerForConditionalGeneration.from_pretrained(MODEL, dtype=torch.bfloat16).eval()
    results = {}
    for f in a.files:
        audio, _ = librosa.load(f, sr=16000, mono=True)
        conversation = [
            {"role": "system", "content": [{"type": "text", "text": "You are a helpful audio expert."}]},
            {"role": "user", "content": [{"type": "audio", "audio": f}, {"type": "text", "text": a.prompt}]},
        ]
        text = processor.apply_chat_template(conversation, add_generation_prompt=True, tokenize=False)
        inputs = processor(text=text, audio=[audio], return_tensors="pt", padding=True)
        with torch.no_grad():
            out = model.generate(**inputs, max_new_tokens=200, do_sample=False)
        answer = processor.batch_decode(out[:, inputs["input_ids"].shape[1]:], skip_special_tokens=True)[0].split("Human:")[0].strip()
        results[Path(f).stem] = answer
        print(f"## {Path(f).stem}\n{answer}\n", flush=True)
    if a.out: Path(a.out).write_text(json.dumps(results, indent=1))

if __name__ == "__main__":
    main()
