# SDFGI lighting experiment

Checkpoint: `a422359` (track characters). The experiment lives on
`codex/lighting-gi`. SDFGI is opt-in through the desktop Lighting menu row or
`--sdfgi`; Direct remains the default. No LightmapGI bake or Android rebuild is
part of this change.

## Lighting inputs

- City ambient fill falls from 0.28 to 0.12. The weak night directional light now
  casts blended shadows on Forward+ Balanced/High, so it does not illuminate
  surfaces through buildings and tunnels. Mobile/Performance omit that added pass.
- Building materials have less uniform metallic response, more varied roughness
  and a less nearly-black diffuse base. Window/neon source radiance no longer
  changes with the capture camera's distance; scene fog handles the distance fade.
- Billboard artwork now uses emission, so SDFGI can capture it as a light source.
  Up to 48 mounted billboards have distance-faded local lights, distributed around
  the track instead of only the opening district. The existing two selected
  shadow lights per view and bounded crossfade slots remain in force.
- SDFGI uses three cascades, 2 m near cells, 1,024 m coverage, half-resolution
  evaluation and occlusion. Forest includes skylight; City/Cell do not.
- The visible road's analytic reflections remain a rendering approximation.
  A shared-mesh, matte shadow-only proxy supplies GI geometry instead, preventing
  those reflections from emitting into the scene. Only one of source/proxy casts
  raster shadows at a time. Direct mode hides proxies entirely.
- Tunnel captures use a fixed average of the chase-strip brightness. The visible
  strips and direct lights still animate, without leaving stale GI pulses.
- Ships, traffic, Cell walkers, debris, particles and short-lived lights do not
  contribute to static GI. They still receive lighting. Jets and explosions keep
  their immediate direct-light response. Water and the animated membrane are
  excluded from static GI geometry.
- Reflection probes provide specular reflections without their old ambient fill
  overriding the SDFGI experiment. The Direct fallback restores their environment
  ambient mode.

## Method

Godot 4.5.2 Forward+, RTX 5070 Ti, 1920×1080 output. Solo uses a 1920×1080
viewport; three players use three 960×540 viewports. The bench warms for five
seconds, then drives a deterministic six-second route with two 120 Hz physics
steps per rendered frame, collecting 360 frames. Direct and SDFGI runs use the
same seed, inputs and cameras. GPU values sum measured viewport timestamps;
rendering CPU excludes gameplay simulation, while full frame intervals include it.
The existing game and background services are left untouched. These short samples
are comparisons, not guaranteed frame rates on every track or machine.

Results and native captures live in `C:/dev/ion-rush-captures/gi`.

Final City route, same camera transforms and six-second simulation:

| Views | Mode | GPU median / p95 (ms) | Frame p95 (ms) | Reported video memory (MiB) |
| --- | --- | --- | --- | --- |
| 1 | Direct | 1.219 / 1.564 | 8.995 | 745 |
| 1 | SDFGI | 2.127 / 3.083 | 8.580 | 1,055 |
| 3 | Direct | 1.600 / 2.069 | 11.542 | 719 |
| 3 | SDFGI | 3.991 / 5.764 | 13.049 | 1,630 |

SDFGI adds roughly 0.9 ms median GPU time solo and 2.4 ms for three views in this
sample, plus around 310 / 911 MiB reported video memory. The lower solo frame p95
with SDFGI is scheduling variation, not an optimization gain. The final scene has
39 billboard lights; their count is capped at 48 for other generated cities.

A second sweep starts the three players a third of a lap apart:

| Biome | GPU median, Direct → SDFGI (ms) | Frame p95, Direct → SDFGI (ms) |
| --- | --- | --- |
| City | 1.47 → 3.90 | 10.68 → 10.38 |
| Forest | 4.25 → 6.86 | 11.06 → 11.79 |

The spread sweep tests independent surroundings rather than three cameras in one
pack. Again, wall-time variation must not be interpreted as an SDFGI speedup.

The GI policy suite passed 1,293 checks across all three biomes (dynamic exclusions,
road proxy/shadow handoff, and graphics/backend fallbacks). Lighting and shadow
suites passed 104 and 125 checks. Native controller-menu tests verify switching
lighting on/off preserves the paused race and selecting Performance disables GI.
The native Cell suite passed 14,814 checks after excluding its moving walkers
from static GI. A desktop run of the Mobile renderer confirmed the `--sdfgi`
request falls back to Direct without shader errors; this is not tablet performance
validation. No Android package was built.

The final same-camera images are `final-static-direct.png` and
`final-static-bounce.png` in the capture directory. `menu.png` shows the new control.

## Assessment and limits

The initial open-city A/B had a subtle visual difference despite the extra GPU
work. SDFGI is therefore exposed for evaluation rather than enabled universally.
It does not replace detailed geometry, convincing materials, local light placement,
direct shadows or accurate reflections. Its coarse geometry and temporal updates
can leak light or lag after fast movement/reset; dynamic geometry cannot act as
an SDFGI occluder. Separate player viewports increase the memory/rendering budget.

Godot's LightmapGI cannot bake in an exported game. Whole-track lightmaps would
require pre-generated layouts and per-layout bakes; that does not fit arbitrary
five-digit seeds. Reusable asset ambient-occlusion baking remains a possible later
improvement, but is not claimed by this experiment.

References: [SDFGI](https://docs.godotengine.org/en/4.5/tutorials/3d/global_illumination/using_sdfgi.html),
[LightmapGI](https://docs.godotengine.org/en/4.5/classes/class_lightmapgi.html).
