# Track character generation

The pre-experiment checkpoint is `dc6ac76` on `main`. The experiment is isolated
on `codex/track-identities`; no earlier work needs to be reverted to compare it.

Previously almost every seed arranged the same components in the same order.
`src/track_profiles.gd` now selects one of six layout recipes from the short seed.
The existing seeded radius, hills, stretch, corner dimensions, feature offsets and
sizes still vary within a family. Adjacent seeds cycle families, making the existing
left/right seed control useful for browsing. Biome and difficulty do not change the
family. GameNight uses the same seed path and needs no extra protocol setting.

## Geometry

- Underpass: four long tunnel corridors with open-air intervals.
- Switchback: three paired radial offsets form physical left/right chicanes;
  difficulty widens or tightens them. These are not just road markings.
- Sky Circus: three separate loops and three jumps, plus the extra Hard flight gap.
- Velocity: a stadium backbone with real straight lines and tangent-continuous
  semicircular ends, retaining seeded height variation.
- Pipeline: repeated half-pipes and tubes with a split between complexes.
- Grand Circuit: retains the established mixed recipe, including seed 00031.

New narrowing components ease the half-width down to 25 / 18 / 15 metres for
Easy / Normal / Hard and back out with a quintic blend. Vehicle hulls remain well
inside the minimum supported deck width. Existing loops, tubes, forks, physics,
surface framing and spatially smoothed banking remain shared components.

Easy removes mandatory gaps and protects open edges in every family. Hard retains
offset landing decks. Tunnel ranges avoid loops, gaps and curved tube surfaces.
Repeated jumps now resolve their own mesh-node takeoff/landing boundaries instead
of incorrectly collecting every gap with the same feature name.

The start and pause menus display the character below the seed. This is a preview
of the pending seed and does not rebuild an active paused race.

## Validation

`tests/track_profiles.gd` checks all six families across all three difficulties
and biomes: road clearance, valid frames, component exclusions, jump lookup,
Easy protections and measurable family characteristics. Its optional `--report=PATH`
exports geometry and metrics for reviewing actual generated courses.

`tests/jumps.gd` traverses every jump across 44 seeds at every difficulty.
`tests/difficulty_soak.gd` runs six-racer, three-lap races for all six families at
each difficulty. `tests/track_features.gd` covers curved decks and forks without
assuming every recipe must contain every component. `tests/menu.gd` verifies
controller navigation and immediate character preview. The general handling,
collision, progress and seeded race tests remain in `tests/run.gd`.

Checked results for this revision:

- 412,625 profile/geometry checks across six families, three levels and three biomes.
- 16,213 jump checks across 44 seeds; all tested approaches landed.
- 108/108 finishers in the six-family, three-level, six-racer race sweep.
- 172 full-world checks, including every Sky Circus jump in City, Forest and Cell.
- 11,798 curved-surface/feature checks; native Windows controller-menu tests passed.
- The general regression sweep also completed 48/48 seeded race finishers.

Native 1080p fixed-camera captures cover Underpass, Switchback, Sky Circus and
Pipeline. Underpass's longer tunnels measured about 1.0 ms median viewport GPU
time in the frozen solo scene on the RTX 5070 Ti. This is a render smoke check,
not a full-race frame-rate guarantee; the user's existing game remained running.

Rendering uses the existing shared road/tunnel shaders and geometry builders;
there are no new per-frame simulations or asset dependencies. Longer tunnel
courses contain more unshadowed tunnel lights; actual render cost still depends
on camera, quality, biome and number of views.
