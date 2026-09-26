# The Cell

Third world setting, selected with left/right in the shared start/pause menu,
GameNight's `biome=cell` setting, or `-- --biome=cell` on the standalone executable.
Procedural geometry and materials require no new downloads or licensed assets.
The course uses the existing difficulty-dependent layout generator; scenery uses
its own seed offset and cannot perturb gameplay randomness.

## Scene

- Double helix towers have two colored backbones and paired base rungs.
- Folded protein knots include smaller alpha helices; broad layered membranes
  give the outer surroundings a different silhouette.
- Mitochondria have raised, folded ridges. A large central nucleus has nuclear
  pores; small vesicles give a sense of scale.
- Cargo organelles walk on six articulated legs along microtubules. Staggered
  footfalls, body sway and cargo bob all use race time, so pause freezes them.
- Opaque tissue simulates a luminous thin rim, with shaded interiors and warm
  key/cool rim lighting. The enclosing membrane is an opaque inward-facing mesh
  with a slowly pulsing procedural pattern, avoiding full-screen transparent
  layers. This is stylized microscopic scenery, not a biological simulation.

Meshes share materials and use spatial MultiMesh batches. Walkers use three
shared batches. Static reflection captures, existing jet lights and desktop SSR
remain available. Mobile uses the existing FXAA/reflection-probe path.

Swept road bounds include extra clearance above jump/flight sections. Placement
reserves each walker's entire movement envelope. DNA backbones and protein
folds use segmented collision approximations so the central openings remain
flyable; organelle bodies have bounding-box collisions updated with animation.

## Validation (2026-09-26)

`tests/cell.gd` checks seeds 31, 421 and 99999 at easy/normal/hard: reproducibility,
scenery and walker clearance, animated bounds, pause stability, moving collisions
and every track centre sample. Run with a native renderer, not the dummy headless
renderer, because the latter cannot read back MultiMesh transforms:

```powershell
godot --path . --audio-driver Dummy --position -20000,-20000 --script tests/cell.gd
```

Controller menu tests cover selecting Cell and wrapping in both directions.
The WebSocket integration test covers switching an existing session to Cell on
the next race, preparing two views, starting and pausing its animation.

Measured with `tests/lighting_bench.gd`, seed 31/hard, 1920x1080 output, quality 1,
RTX 5070 Ti / Ryzen 5900X, vsync off, after a five-second warm-up. Three views are
960x540 each. Fixed cases boost all six craft; the moving case runs the simulation
and scenery animation. Background workloads were not stopped, so CPU wall-time
is a snapshot rather than an isolated hardware benchmark.

| Case | Samples | Wall median / p95 | GPU median / p95 |
| --- | ---: | ---: | ---: |
| Forward+, solo, fixed camera | 300 | 5.19 / 7.29 ms | 1.09 / 3.26 ms |
| Mobile, three views, fixed camera | 300 | 3.31 / 4.90 ms | 0.78 / 1.87 ms |
| Mobile, three views, moving | 900 | 7.43 / 10.90 ms | 0.76 / 2.21 ms |

These are PC measurements using both rendering paths, not Galaxy Tab S9+
measurements. The Android APK still needs device playtesting.
