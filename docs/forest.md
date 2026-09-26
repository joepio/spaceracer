# Forest biome — September 26, 2026

World in the start menu selects City or Forest (Verdant Reach), with an immediate
preview and controller navigation. GameNight exposes the same choice for the
next race. Standalone accepts `--biome=forest` after `--`. Replay identity is now
seed, difficulty and world; all three appear in the HUD and results.

Forest uses lower hills over a reflective lake, 260–520 metre branching trees,
folded leaf canopies, buttress roots, mossy islands and fern clusters. Seed 31
produces 865 trees and 4,325 fern clusters. Three deterministic tree variants
are instanced in spatial chunks. Conservative geometry bounds exclude the
swept road and flight corridors. The existing loops, tubes, splits and
difficulty-dependent jumps remain; entering the lake triggers normal recovery.

Daylight, green ambient fill and restrained mist distinguish this world from
the night city. Shader wind and water ripples use the paused race clock.
Reflections use existing screen-space reflections and three static probes;
the forest does not add per-tree lights or rebuild meshes each frame. Split
screen shortens directional shadow distance; Performance disables these shadows.
All forest geometry and materials are procedural, with no new downloaded assets.

## Validation

- 2,331 forest checks passed, including scenery reproducibility, independent
  road-clearance samples, animation clocks and water recovery.
- All 72 AI racers finished across twelve seed/difficulty combinations.
- Controller menu and 43 flight checks passed.
- Source and packaged native GameNight integration passed, including Forest
  preparation, deferred world changes and City re-preparation.
- Native Forward+ renders were inspected and foliage/fog refined in two passes.

## Performance

RTX 5070 Ti, Ryzen 9 5900X, Godot 4.5.2 Forward+, High, 1920×1080 output with
four 960×540 views. Moving race through the jump, seed 31, Normal, five-second
warm-up and 1,200 frame samples. The old playtest was closed during measurement.

| Metric | Result |
|---|---:|
| Measured GPU mean / p95 | 4.523 / 6.214 ms |
| Wall frame mean / p95 | 13.369 / 17.440 ms |
| Mean system CPU during samples | 86.5% |
| Reported video memory | 793.7 MB |

GitHub runners, wasm-opt and Rust compilation were active and left untouched.
Wall timings include this CPU contention and do not establish a guaranteed
frame rate. Raw timings, CPU/GPU telemetry, screenshot and background-process
snapshot are under `C:/dev/ion-rush-captures/lighting/forest-moving-4*`.
Solo visual reference: `C:/dev/ion-rush-captures/forest/forest-refined.png`.
