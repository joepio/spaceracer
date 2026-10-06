# Desert — Scorched Dunes

Fourth world setting, selected with left/right in the shared start/pause menu,
GameNight's `biome=desert` setting, or `-- --biome=desert` on the standalone
executable. All geometry and materials are procedural; no new assets.
The course uses the existing layout generator (with a lower, forest-like
altitude profile); scenery uses its own seed offsets.

## Landscape

- `src/desert_terrain.gd` builds one 7.7 km height field shared by the visible
  mesh, prop placement and collisions: wind-aligned dune crests on a broad
  swell, stepped flat-topped mesas, and a broken ring of great mesas on the
  horizon.
- Canyon walls are raised along the course from the distance to the nearest
  road segment. Their strength alternates around the lap, so canyon runs and
  open dune sea take turns. Profile tunnels become taller, steeper slot canyons
  (`n.canyon`); the neon tunnel tube is not built in the desert.
- The same envelope as the forest keeps the full road cross-section, jump and
  flight corridors clear: terrain is capped below every segment and only rises
  beyond the road plus margin. Loops and jumps carve but never anchor walls.
- Three open basins (`Terrain.worm_basins`) suppress walls and flatten the dunes
  so the sandworm has room to breach.

## Props

- Hoodoos (stacked drums under a cap stone), boulders and saguaro cacti are
  spatially batched. Solid cores collide; placement uses swept road bounds.
- Natural sandstone arches span the road on straight, open stretches. Each arch
  is checked against every nearby road node with a 70 m+ clearance and adds
  segmented collision boxes along its legs and lintel.
- `desert_ground.gdshader` mixes rippled sand with banded sandstone on steep
  faces; fine laminations fade with distance to avoid moire.
  `desert_rock.gdshader` shares the world-space strata.

## Sandworm

`src/sandworm.gd`: a 46-segment body (MultiMesh) and a three-jawed head with
rows of teeth. Each basin site has a path that rises steeply out of the sand on
one side, crosses about 95 m above the road with a flat crown, and dives into
the sand on the other side. The worm erupts when a pilot is 230–480 m before a
site, so the pack passes under the arc; it also erupts on its own after a quiet
spell. Sand sprays from each hole while the body passes through it: puffs, a low
rolling ring and heavier falling grains, all deterministic from the race clock.
The worm is visual only and never collides.

## Validation

`tests/desert.gd` checks determinism, relief, prop density, a clear road
cross-section, canyon wall coverage, arch clearance and the worm's eruption,
crown height, dust and clock resets. `tests/desert_render.gd` captures chase and
wide shots of the worm, a canyon, an arch and an aerial overview:

```sh
godot --path . --script res://tests/desert_render.gd -- --output=/abs/dir --seed=31
```
