# Exhaust optics and heat

Each nozzle has an original additive flare shader: a thin horizontal streak,
soft core and faint optical ring. It faces each split-screen camera independently,
fades when viewed from the nose, and samples the depth at the nozzle to suppress
the whole flare when scenery or another craft hides its source.

Boost increases each existing nozzle light from 2.6 to a varying 8–12 energy and
extends its range from 19 to 28 metres. Core emission rises from 3 to 8–13 and its halo expands.
No extra dynamic lights or shadow maps are added. Player exhaust colors persist.

Boost also emits six jagged plasma bolts per nozzle, each with a secondary fork.
Their independent bursts redraw at irregular 5–9 Hz rates, with different angles,
reach and dark intervals. One shared mesh supplies the fixed topology; GPU vertex
animation supplies the movement, adding just two draws per craft. The main jet
ribbons bend into uneven tongues and their length surges independently per engine.
Local light, core emission and flare intensity pulse with bounded irregular
modulation. All animation uses simulation time, never gameplay random numbers.
Discharges are hidden outside boost and during recovery.

A single transparent ribbon per nozzle reads the opaque screen behind the
exhaust and refracts it with animated turbulence. The distortion is roughly
sub-pixel at normal throttle and a few pixels during boost at 1080p, with soft
edges and depth rejection to protect foreground surfaces. It draws before the
additive jets, so it cannot erase their light. It does not refract other
transparent particles. Both shaders use the simulation clock and stop on pause;
crash/recovery hides them. They also respond while revving during countdown.

The reference was Growing Guns' [rocket flare overlay](https://github.com/ontola/growing-guns/blob/68cd40fc080acf6b5016fa8fd49b909816bc3099/scripts/lens_flare_overlay.gd)
and associated shader. No source or assets were copied. Screen/depth sampling
follows [Godot's screen-reading shader documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html).
Godot 4.5 Mobile has a [depth/MSAA bug](https://github.com/godotengine/godot/issues/103425),
reproduced by the occlusion test. Mobile viewports use FXAA instead of MSAA at
Balanced/High quality so readable depth works. Forward+ keeps 2x MSAA.

## Validation

`tests/effects.gd`: 37 checks passed for startup, throttle, boost illumination,
recovery cleanup, controller responses and exhaust behavior.
`tests/jet_render.gd` verifies actual rendered pixel changes from heat, animation,
pause, changing electrical branches, visible flares and a narrow obstacle covering only the light source.
Forward+, Mobile and OpenGL passed; none leaked flare pixels around the obstacle.
Touch and menu checks also pass.

Fixed seed 31 at 1080p on the RTX 5070 Ti, with all six racers boosting:

| Scene | Median total GPU time | Median frame time |
| --- | ---: | ---: |
| City, one 1080p view, new optics disabled | 1.185 ms | 4.282 ms |
| City, one 1080p view, new optics enabled | 1.242 ms | 3.798 ms |
| City, three 960x540 views | 1.514 ms | 6.399 ms |
| Forest, Mobile, three 960x540 views | 1.549 ms | 7.252 ms |
| Forest, Mobile, three views with electrical discharges | 1.536 ms | 6.713 ms |

These are short whole-scene native captures, not tablet performance claims.
CPU/background activity and GPU clock variation limit the precision of the
enabled/disabled difference. Optics add four small draw calls per visible craft,
using the viewport's shared screen/depth buffers. The later electrical discharge
pass adds two more draws per craft. Use `tests/lighting_bench.gd`
with `--boost`, `--views=3`, or `--ablation=no-jet-optics` to reproduce.
