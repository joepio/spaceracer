# Ocean — Abyssal Reef

Fifth world setting, selected like the others (`biome=ocean`, or
`-- --biome=ocean` on the standalone executable). Everything is procedural.

## Landscape

- `src/ocean_terrain.gd` reuses the desert height field with strata steps
  turned off, so the same seeded ranges become rounded reefs and seamounts.
  Reef walls line the course, profile tunnels become deep trenches
  (`n.canyon`, section "DEEP TRENCH") and the three open basins become sand
  plains for the octopuses.
- `src/ocean_reef.gdshaderinc` colours seafloor and loose rock: dark rock with
  soft patches of sponge and coral, polyps up close, algae on upward faces and
  animated caustics from the surface.
- `src/ocean_sky.gdshader` is the view from below: blue fading to black, light
  shafts and Snell's window overhead with a rippled surface.
- `src/world.gd` sets dense blue-green fog, a steep cool sun and teal ambient.

## Flora (`src/ocean.gd`)

`Ocean` extends the desert scenery for its swept-course clearance, boulders and
arches. It adds spatially batched kelp, lantern weed (crozier stems with glowing
bulbs and soft halos), sea fans (procedural lattice, alpha scissor) and tube
sponges with glowing lips. All sway in `src/ocean_plant.gdshader` from the race
clock. Stalks, fans and sponges get small collision boxes.

## Fauna (`src/ocean_life.gd`)

- Fish schools orbit beside the road; tails wiggle in the shader.
- Jellyfish swarms (additive, pulsing bells, trailing tentacles) are placed only
  where `course_clear` keeps them out of the road and flight envelope.
- Manta rays glide in banked circles with flapping wings.
- Giant octopuses sit 220-300 m from the road on open sand. The mantle breathes
  and shifts colour; the eight arms are one MultiMesh whose curl is integrated
  on the GPU from per-arm custom data. Arms can never reach the road.
- Marine snow wraps around the camera, bubble columns rise from vents and light
  shafts lean with the sun.

Only the octopus bodies collide. All motion follows the pausable race clock.

## Checks

- `tests/ocean.gd`: determinism, populations, road clearance (terrain, props,
  collision volumes, octopus reach, jellyfish), reef walls and the race clock.
- `tests/ocean_render.gd -- --output=DIR --seed=N`: chase shots, octopus,
  jellyfish, lantern weed, sea fan, fish and an overview.
