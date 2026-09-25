# Track diversity validation

Every seed now has an unguarded sky section, a rideable half-pipe, an interior
magnetic tube and a two-deck fork. Feature positions and sizes use a separate
seeded stream, preserving the original centreline. The tube opens progressively
at either end; return toward its bottom before the exit. Its closed section wraps
around the ceiling, including racer contacts. Forks have a real centre gap and
merge into the same race progress. Leaving an open edge enters the existing
free-flight and recovery system.

The mesh, ship orientation and flight landing tests use the same curved-surface
geometry. The wall normal accounts for longitudinal bends and banking. Flight
projection refines against the curved deck; a centreline-only projection was
insufficient for wall landings. Pipe meshes use 24 segments across their width,
with explicit smooth surface normals, cyan guide strips and occasional rings.
Buildings still reserve conservative envelopes around the full circuit.

Validation on seed variants:

- 197,013 simulation checks passed across 40 track seeds, including 48/48 AI
  finishers in the full-race soak (longest race 115.19 seconds).
- 8,418 feature checks passed: reproducibility, geometry/projection agreement,
  open-edge takeoff, both fork routes and merges, ceiling seam continuity,
  seam collisions and a controlled landing onto a tube wall.
- 17,455 city and rendered-building clearance checks passed across eight seeds.
- 43 flight checks, 25 exhaust checks, the controller/seed menu test and 62
  lighting-budget checks passed. Native exhaust validation also checked actual
  rendered particle displacement (26 checks).
- Source/headless and packaged/native Gamenight protocol integration passed.
- Native captures inspected open road, half-pipe wall riding, tube entry/interior/
  ceiling/exit and both fork branches. Physical controller testing was not repeated.

Four-view High rendering checks at 1920×1080 total, RTX 5070 Ti, Godot 4.5.2:
600 uncapped samples after a five-second warmup measured mean GPU costs of
1.52 ms (half-pipe), 1.49 ms (tube) and 1.30 ms (fork). A short 1,200-frame moving
tube run measured 1.64 ms mean GPU time and 19.35 ms p95 wall interval. Background
runner CPU contention remains relevant; these are smoke checks, not a promise of
locked frame rate. Logs and raw samples remain in the development capture folder
under `lighting/diversity-*`.

`tests/track_render.gd -- --out=<folder>` captures the new sections.
`tests/lighting_bench.gd -- --views=4 --landmark=tube` profiles them;
`halfpipe`, `split` and `open` are also accepted landmark names.

The exhaust update is included: sparks eject backward at vehicle speed plus
220–380 m/s, with another 220 m/s under boost. The fixed particle budget is
unchanged; movement integrates from the effects clock and pauses correctly.
