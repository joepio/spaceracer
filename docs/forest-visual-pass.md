# Authored forest replacement — 2026-09-26

The rejected procedural branch/crown meshes are removed. Forest now instances the
Pine Tree (evolveduk) and Tree Bake Upload birch (restlessmonkey) from the existing
GamesNotDeveloped Godot Procedural Forest Demo, pinned to commit
623212ffeb4efbf4c95323a4a6a57e726be4f6e9. Both models are CC BY 4.0; original
licenses, source links and adaptation details are in third_party/forest-demo.
Credits are also available in the game on Windows and Android.

Imported scene transforms are preserved and normalized to unit height. Authored
meshes and generated Godot LODs are cached, then shared in spatial MultiMeshes.
No runtime mesh generation or asset downloads. The seeded layout mixes 70% pine
and 30% birch, varied rotation, modest width variation, and 80–650 metre heights.
After adding the landscape, seed 31 contains 768 trees and 4,132 ferns; seed 421
contains 791 and 4,251. Trees only occupy dry ground, with roots seated into slopes.
Actual transformed mesh envelopes protect track and jump corridors. Trunk
sections remain solid collision obstacles; foliage cards remain flyable.

Textures are capped at 1024px, VRAM compressed for desktop and Android, with
mipmaps. Foliage writes depth with alpha scissor, receives directional light and
casts shadows. No emissive or backlight hack. Birch materials were converted from
the old specular/gloss workflow to rough nonmetallic PBR; pine needles receive a
muted green tint. Existing reflective water and sky remain.

The landscape replaces all individual tree-island spheres with a 7.68 km square
height field (24 metre grid, 204,800 triangles, spatially culled in 384 metre tiles).
Broad seeded hills form connected land and submerged valleys. Road clearance
includes a grid-cell safety margin and smooth side slopes. The mesh, plant heights,
shore-depth map and swept flight/debris collisions share the same triangulated
height data. Ground uses a grass/earth/stone material with damp shoreline banks.

## Fixed native benchmark

Same seed 31, hard Forest, fixed 7%-of-track camera from tests/forest_render.gd.
100 warmup frames, 180 samples. RTX 5070 Ti / Ryzen 5900X, live playtest and other
background processes left running. Timings are scene viewport render cost,
not a tablet FPS guarantee. Vsync caps median frame interval around 8.33 ms.

| Renderer | Internal resolution | GPU median | CPU render median | Draws | Primitives |
| --- | --- | --- | --- | --- | --- |
| Forward+ | 1600×1000 | 1.342 ms | 0.680 ms | 395 | 2,271,334 |
| Mobile on desktop GPU | 1280×800 | 0.523 ms | 0.572 ms | 361 | 1,801,699 |

The first uncompressed/unmipmapped authored-tree pass cost ~2.945 ms GPU. The final
textures reduce bandwidth and foliage shimmer without replacing the tree meshes.
Actual Samsung Tab S9+ timing remains unmeasured.

Validation: tests/forest.gd checks density, shared meshes, normalized transforms,
seed determinism, course clearance and water/reset behavior: 2,730 checks, no
failures, 72/72 bot finishers. tests/world_jumps.gd: 40 checks, no failures.
tests/forest_terrain.gd: 39,700 checks across nine seed/difficulty combinations,
including water/land balance, track clearance, swept impacts, nearest-hit ordering,
mesh/sampler agreement and face winding.
The foliage material lighting fixture verifies a dark underside (17.5% of lit-top
luminance on Forward+). Native screenshots verify complete imported trees.

Reproduce:

```powershell
godot --path . --audio-driver Dummy --resolution 1600x1000 --script tests/forest_render.gd -- --demo --seed=31 --difficulty=hard --biome=forest --tag=desktop
godot --path . --rendering-method mobile --audio-driver Dummy --resolution 1600x1000 --script tests/forest_render.gd -- --demo --touch --seed=31 --difficulty=hard --biome=forest --tag=mobile
```

Screenshots default to build/forest-<tag>.png; --output=<absolute path> overrides.
