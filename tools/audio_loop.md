# Audio iteration loop

A repeatable way to judge and improve SpaceRacer's sound without listening to
every change by hand. It records real gameplay through the game's own mix,
scores it with audio AI models, and lets a search tune the sound recipes.

## Setup (once)

```sh
python3 -m venv ~/aj
~/aj/bin/pip install --index-url https://download.pytorch.org/whl/cpu torch torchaudio
~/aj/bin/pip install transformers librosa soundfile pyloudnorm matplotlib scipy
```

The models download from Hugging Face on first use (about 1 GB):
CLAP `laion/larger_clap_general` (text-to-audio match) and AST
`MIT/ast-finetuned-audioset-10-10-0.4593` (AudioSet labels). CPU is enough.

## The loop

1. **Render** the sounds from their recipes: `python3 tools/render_racer_audio.py`
   (numpy + ffmpeg only). Then let Godot reimport:
   `godot --headless --path . --editor --import --quit`.
2. **Record** a scripted 38-second race through the real mix:
   `godot --headless --path . --script res://tools/audio_scenario.gd -- --out=build/audio-loop/run`.
   It runs the countdown and launch, full throttle, two boosts, a brake and a
   coast, then a missile, railgun, sentry gun, EMP, warp and glide bomb, with
   three bots racing. It writes `run.wav` and `run.json` (event markers).
3. **Judge** it: `~/aj/bin/python tools/audio_judge.py build/audio-loop/run.wav --reference fzgx.wav`.
   Writes `run-report.md/.json/.png`:
   - *match*: how strongly CLAP prefers the moment's description ("a sci-fi
     railgun firing a sharp electric energy shot") over bad ones (hiss, wind,
     vacuum cleaner, cheap toy), 0 to 1.
   - *bad tags*: AudioSet probability mass on hiss, static, wind, water, hum,
     appliances. Lower is better.
   - LUFS per moment, so cues can be checked against the engine bed.
   - *exciting mix*: CLAP's verdict on the whole run as "an exciting
     high-energy futuristic racing game".
   - with `--reference`: CLAP similarity and spectral balance against a
     reference recording (we used an F-Zero GX time-attack video from
     archive.org; keep such files local, they are not ours to commit).
   - a spectrogram with the event markers, to eyeball what the numbers say.
   `--clips assets/audio/racer` scores every sound file on its own.
4. **Search**: `~/aj/bin/python tools/audio_search.py boost rail warp --steps 30`
   hill-climbs each recipe's numbers against the judge and saves winners to
   `tools/audio_params.json`. Go back to step 1.

The AI judge is a guide, not the final word: it can be fooled, so check the
spectrogram and give the result a real listen on ManCave before calling a
sound done. Mix levels (trims in `src/race_audio_mix.gd` and the cue table in
`src/game_audio.gd`) are set by hand from the LUFS column.
