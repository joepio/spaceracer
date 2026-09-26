# Forest foliage, water and lighting pass — 2026-09-26

Seed 31, Forest/Hard. Static view at 7% of the circuit, 100 warm-up frames and
180 sampled frames. RTX 5070 Ti, Ryzen 9 5900X; existing playtest/background work
left running. These are desktop measurements, not Samsung Tab S9+ results.
VSync limits whole-frame timings to about 8.33 ms, so compare measured viewport
GPU/CPU times and geometry rather than claiming an FPS improvement.

| Renderer | Before GPU | After GPU | Before CPU | After CPU | Before primitives | After primitives | Before / after draws |
|---|---:|---:|---:|---:|---:|---:|---:|
| Forward+, 1600×1000 | 1.298 ms | 1.654 ms | 1.241 ms | 0.821 ms | 2,089,156 | 2,107,104 | 385 / 438 |
| Mobile, 1280×800 | 0.356 ms | 0.789 ms | 0.644 ms | 0.566 ms | 1,606,560 | 1,830,096 | 305 / 385 |

After: 971 trees (up from 865) and 5,319 ferns. Most trees are 340–650 metres tall;
six silhouettes and an 80–340 metre lower layer add variation without losing the
huge-forest theme. Photographed CC0 leaf/bark textures are bundled with provenance.
Distant foliage has under half the vertices; distant wood uses a third of the
near mesh's longitudinal divisions. Smooth trunk/crown normals, lower ambient
fill and short-range mobile shadows address washed-out shaded sides.

The intermediate dense version cost 2.801 ms GPU and 3,350,580 primitives in the
same desktop view; mipmaps, simpler distant meshes and removing unnecessary
trunk segments brought that to the final values above. GPU cost remains higher
than the old sparse, untextured forest, especially with mobile shadows enabled.
The water uses dielectric shading, two mipmapped ripple samples, shallow swells,
a baked shoreline field and the existing three once-captured reflection probes.

Reproduce the final view with Godot 4.5.2:

```powershell
godot --path . --audio-driver Dummy --resolution 1600x1000 --script tests/forest_render.gd -- --demo --seed=31 --difficulty=hard --biome=forest --tag=desktop
godot --path . --rendering-method mobile --audio-driver Dummy --resolution 1600x1000 --script tests/forest_render.gd -- --demo --touch --seed=31 --difficulty=hard --biome=forest --tag=mobile
```

Screenshots default to `build/forest-<tag>.png`; `--output=<absolute path>` overrides
this. Actual tablet thermals/frame rate still require device testing.

Validation: `tests/forest.gd` checks determinism, dominant giant-tree density,
variation, LOD clearance identity, race-clock animation, route clearance and
water crashes, then runs 72 AI finishers across worlds' difficulty/seed cases.
`tests/world_jumps.gd` covers actual scenery collision on both forest and city jumps.

## Leaf underside correction

The initial pass still had inverted winding on canopy interiors and trunks,
and radial crown normals on flat leaf cards. With two-sided rendering these
could turn the underside toward the sun. The corrected geometry uses clockwise
faces with matching outward normals, and leaf normals follow each card plane.
Artificial leaf/fern backlighting is removed. Canopy filler has darker, occluded
interior shading and no specular highlight. Ambient/sun settings are unchanged.

`tests/foliage_lighting.gd` checks winding/normal agreement across all six models
and both detail levels, then renders the same leaf from above and below under
one overhead light. On Forward+ the underside/top luminance ratio is 0.156;
on Mobile it is 0.146 (required below 0.35). Both checks passed. Run natively
with `--script tests/foliage_lighting.gd`; add `--rendering-method mobile` for Mobile.
Headless mode runs only the geometry checks.
