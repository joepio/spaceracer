# Shadow range and transitions

The previous directional shadows stopped at 380 m solo, 220 m split-screen,
or 170 m on Mobile. Their outer 20% fade lasted only about 0.11–0.19 seconds at
390 m/s. Two unblended cascades also exposed resolution changes on large scenery.
Local city shadows were reassigned by directly toggling shadow_enabled.

The current sun settings, shared by Forest and Cell:

| Renderer / quality | Solo range | Split-screen range | Cascades |
|---|---:|---:|---:|
| Forward+ Balanced / High | 1,400 m | 1,100 m | 4 solo / 2 split-screen |
| Forward+ Performance | 800 m | 800 m | 2 |
| Mobile | 650 m | 520 m | 2 |

Cascades blend, and shadows fade across the outer 45% of the range. High-detail
solo splits are at 6%, 18% and 46%, keeping a small near cascade for vehicles.
Split-screen's near cascade ends at 12%. Pancaking
is disabled to avoid clipping giant Cell objects at the shadow frustum edge.
Compatibility retains the existing unshadowed directional-light fallback.

City fixtures and billboards select two shadow lights per view, with 45 m of
selection hysteresis. Old and new lights crossfade over 0.5 seconds. Allocation
is capped at four slots per view, 16 total, including outgoing lights. New lights
wait when all slots are fading. No light can abruptly lose a visible shadow just
because another fixture became slightly closer. Pausing freezes the fade clock.
Streetlight and billboard shadow-distance fades also extend farther.

## Desktop measurements

Godot 4.5.2 Forward+, RTX 5070 Ti / Ryzen 5900X, High, seed 31, Hard, fraction
0.055, six racers, 1920×1080 output; three views render at 960×540 each.
Five-second warmup, 240 uncapped sampled frames per fixed capture. GPU figures
sum root and player viewport timestamps. These are paired scene samples, not
whole-game FPS guarantees. The user's separate game remained running; runner
services and other background work were left untouched.

| Scene | GPU median before → after | Render CPU median before → after | Frame interval p95 before → after |
|---|---:|---:|---:|
| Cell solo | 1.051 → 1.168 ms | 1.065 → 2.114 ms | 4.313 → 4.707 ms |
| Cell three views | 1.439 → 1.596 ms | 2.913 → 4.378 ms | 7.191 → 9.785 ms |
| Forest solo | 1.847 → 2.381 ms | 1.735 → 2.663 ms | 4.595 → 6.437 ms |

For the cascade-count decision, a scripted six-second forest route uses exactly
two 120 Hz simulation ticks per rendered frame, 360 samples, three views. Final
camera transforms match between runs. Four versus two cascades at the same
1,100 m range measured 4.707 → 4.261 ms GPU median and 8.581 → 6.807 ms rendering
CPU median. Two cascades are therefore used in split-screen. The final moving
run's full frame interval was 19.007 ms median / 22.479 ms p95 with the separate
game still running; these results do not establish steady 60 FPS in dense forests
on all machines. The shorter fixed captures above exclude gameplay simulation.

Captures and CSV/JSON samples are in `C:/dev/ion-rush-captures/shadows`. The
`legacy-shadows` ablation in `tests/lighting_bench.gd` reproduces the previous sun
settings for comparison; `--scripted-motion` gives deterministic moving samples.
Android was not rebuilt or measured on the tablet.

`tests/shadows.gd` checks actual local-shadow crossfades, pause behavior and slot
bounds under rapid travel. `tests/lighting.gd` checks the quality transitions and
shared lighting budget with four views.

## Baking

Whole-scene lightmaps are static and must match the geometry arrangement. Each
procedural seed moves the track and scenery, so a single baked track lightmap
cannot be reused for every seed. Reusable asset ambient occlusion or a per-seed
shadow cache remain possible future optimizations; neither is implemented in
this change. Dynamic ships, walkers, jets and weapons still require live lighting.

References: [Godot directional shadows](https://docs.godotengine.org/en/4.5/classes/class_directionallight3d.html),
[Godot lightmap baking](https://docs.godotengine.org/en/4.5/tutorials/3d/global_illumination/using_lightmap_gi.html).
