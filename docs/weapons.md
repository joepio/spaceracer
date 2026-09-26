# Pickup weapons

Pickups use deterministic seed-based rolls and one carried item per racer. Each
row can be collected once per lap by each player, including sparse GameNight
slots. X activates; LT remains brake. Keyboard defaults are X, slash, P and C.
Touch shows a Use button when carrying an active item. Landing assist is passive:
its HUD label says AUTO and it does not need or show a Use button.

## Balance

| Item | Behaviour |
| --- | --- |
| Cruise missile | Locks the leader at launch, with a straight red targeting laser. The final approach lasts 550 ms. A fresh turn above 24 lateral G in the final 230 ms evades it; road turns also require a brake slide. Hit: 38 shield damage and 34% speed loss. |
| Warp drive | 2.8 seconds of course autopilot, up to 530 m/s. Phases through traffic and attacks; extends across a gap to hand control back on solid track. Tapers speed for the upcoming bend. Ground activation only. |
| Sentry drone | Eight-second escort. Shoots the nearest rival ahead within 220 m of progress and 190 m spatial distance, with a forward cone and scenery occlusion. Four shield damage every 400 ms. |
| Landing assist | Single-use automatic guidance during the final 300 ms of a predicted top-side touchdown. Levels attitude and damps lateral/descent velocity with four visible thrusters. The assisted touchdown is perfectly aligned and damage-free. Does not teleport across gaps or bypass scenery/underside collisions. |

Landing assist takes 18% of rolls. Within the remaining 82%, missile/warp/drone
odds interpolate from 18/28/54% at the front to 30/36/34% at the back.
A leader's missile roll becomes a drone. Inventory survives an
invalid activation, but crashes discard it. Heavy hits give 1.1 seconds of
protection against stacked attacks; respawning gives two seconds. Empty shields
use the existing crash, debris and manual Y recovery system.

Unassisted landing damage uses the local deck frame: normal descent above 8 m/s,
attitude error beyond 5 degrees and lateral speed above 8 m/s contribute, capped
at 65 shield points. Fatal energy loss and the existing extreme-impact limits
produce a wreck. A depleted hull receives 25 shield points after manual recovery
so it cannot be trapped at a mandatory jump; ordinary resets retain their cost.

## Validation (2026-09-26)

- Landing extension: `tests/landing.gd` passes 31 checks, including increasing
  impact/angle/slip damage, guidance at 30/60/120 Hz, single-use consumption,
  withheld activation over gaps, scenery and underside collision, fatal damage
  and manual recovery. `tests/flight.gd` passes 54 checks and `tests/jumps.gd`
  passes 18,058 checks across normal/hard seeds. `tests/crashes.gd` passes 35.
  The updated forest race suite passes 2,730 checks with 72/72 finishers.
  `tests/landing_render.gd` captures a real guidance intervention with the
  production camera, HUD and four plasma thrusters.
- `tests/weapons.gd`: 41 checks, zero failures, including a dodge produced by
  actual steering/braking physics, late versus early turns, per-player pickup
  claims, deterministic rolls, drone occlusion, warp gaps/finish and shield death.
- `tests/crashes.gd`: 35 checks, zero failures.
- `tests/world_jumps.gd`: 40 checks, zero failures.
- `tests/forest.gd`: 2,730 checks, zero failures; 72/72 simulated racers finished
  with combat enabled (before the final odds and warp exit-speed refinements).
- Touch input and native menu checks pass. GameNight activation is covered by
  both sparse controller-frame unit checks and the native integration suite.

`tests/weapon_render.gd` holds a repeatable three-player scene with all three
items active. Sixty warmup frames precede 180 measured frames. Results below
are on an RTX 5070 Ti / Ryzen 5900X, with other desktop processes running.

| Renderer / biome | Per-view resolution | Sum of view GPU times | Sum of view CPU times | Frame median / p95 |
| --- | --- | --- | --- | --- |
| Forward+ / forest | 960 × 540 | 3.309 ms | 2.473 ms | 8.357 / 9.771 ms |
| Forward+ / city | 960 × 540 | 1.370 ms | 1.247 ms | 8.333 / 8.370 ms |
| Mobile / forest | 640 × 360 | 1.178 ms | 1.832 ms | 16.666 / 16.703 ms |
| Packaged Forward+ / forest | 960 × 540 | 2.980 ms | 2.352 ms | 8.337 / 16.875 ms |

View timings exclude final screen composition. These are whole-scene timings,
not the isolated cost of weapons. The Mobile row uses the desktop GPU and a
60 FPS cap; it is not a Samsung tablet measurement. Visual checks cover both
biomes and Mobile rendering. Warp distortion stays in its own player's view;
HUD text remains sharp. Weapons add no shadow lights or reflection cameras;
pickups share a MultiMesh and transient shots/impacts use bounded mesh pools.

Example capture command (add the engine executable before these arguments):

```text
--path . --audio-driver Dummy --position -20000,-20000 --resolution 1920x1080 --script tests/weapon_render.gd -- --demo --players=3 --seed=31 --biome=forest --difficulty=hard --output=weapons.png
```
