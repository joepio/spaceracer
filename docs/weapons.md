# Pickup weapons

Pickups use deterministic seed-based rolls and one carried item per racer. One
in three of the original stations remains, with three lanes at each. Collecting
a lane hides it globally for two seconds; other lanes stay available. A 450 ms
mint flash illuminates the collector and nearby road, with expanding world-space
rings at the pickup and craft. The pickup scales back in over approximately
170 ms. Each player can collect once per row per lap, including sparse GameNight
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
| EMP | World-space spherical pulse, expanding to 220 m over 650 ms. Rivals inside lose engines for 2.2 seconds; the emitter is exempt. Momentum and aerodynamic steering remain, while throttle, boost, ground strafe and landing guidance are disabled. Cancels warp; a warp interrupted above missing deck becomes real flight. No shield damage. Two-second reboot protection prevents chain locks. |
| Jammer | Six-second transmitter, 260 m forward range and 28-degree half-angle. Distance and angular falloff scale visual noise and random steering/strafe/pitch perturbations, capped at .38/.32/.18. Strongest source wins; effects do not add together. No buttons/throttle/brake modifications. |

Landing assist takes 18% of rolls, EMP 16% and Jammer 14%. Within the remaining 52%, missile/warp/drone
odds interpolate from 18/28/54% at the front to 30/36/34% at the back.
A leader's missile roll becomes a drone. Inventory survives an
invalid activation, but crashes discard it. Heavy hits give 1.1 seconds of
protection against stacked attacks; respawning gives two seconds. Empty shields
use the existing crash, debris and manual Y recovery system.

Unassisted landing damage uses the local deck frame: normal descent above 18 m/s,
attitude error beyond 12 degrees and lateral speed above 18 m/s contribute, capped
at 18 shield points. The coefficients are reduced to .10 for descent, 5 for the
normalized attitude term and .035 for slip. A representative 55 m/s descent with
20-degree roll costs about 4 points instead of about 18. Speed loss is .2% per
point (maximum 3.6%). Top-side capture accepts nose/up dot products above .4,
approach above 45 m/s and descent below 115 m/s (140 on purpose-built jump decks).
Fatal energy loss and extreme impacts produce a wreck. A depleted hull receives 25 shield points after manual recovery
so it cannot be trapped at a mandatory jump; ordinary resets retain their cost.

## Validation (2026-09-26)

- Pickup/landing rebalance: 36 pickup checks, 34 landing checks, 41 weapon checks,
  54 flight checks and 18,058 jump checks pass. The forest suite passes 2,730
  checks with 72/72 finishers. `tests/weapon_render.gd -- --pickup-showcase` checks
  shared disappearance, collector light and rings in three-player rendering;
  add `--pickup-respawn` to verify their removal and the item's reappearance.
  Pickup flashes use one brief shadowless light per collecting racer, with
  pooled ring meshes. No light remains active after the flash ends.
  Packaged GameNight integration passes when run separately; the first run
  alongside Android export/render capture exceeded its 15-second reprepare timeout.
- Jammer: seeded, smoothly interpolated eight-Hz control noise uses simulation
  time and controller slot. Inputs are copied before applying interference,
  preserving GameNight frames and local controls. `tests/jammer.gd` checks cone
  orientation, distance/angle falloff, expiry, owner exclusion, input bounds,
  reproducibility, EMP/warp/respawn interactions and actual race input routing.
  `tests/weapon_render.gd -- --jammer-showcase` captures three-player output:
  an unaffected emitter with its extending parabolic dish, a close heavily
  disrupted rival and a distant lightly disrupted rival. The dish and amber
  wavefronts use pooled meshes, with no added lights or reflection cameras.
  All 27 jammer checks and 41 weapon checks pass. The forest race suite passes
  2,730 checks with 72/72 finishers. Desktop captures measured 1.387 ms summed
  GPU view time for three city views at 960 × 540 each, and 1.196 ms for the
  Mobile forest renderer at 640 × 360 each. These are whole-scene measurements
  on the RTX 5070 Ti, not measurements on the tablet.
- EMP: `tests/emp.gd` passes 23 checks covering propagation, owner exemption, spatial radius,
  airborne targets, coasting, boost blocking, automatic reboot, protection,
  warp interruption over gaps, landing guidance and input/countdown handling.
  Visuals use pooled sphere/ring meshes, a shared procedural electrical shader
  and per-player screen interference; no extra shadow lights or reflection passes.
  `tests/weapon_render.gd -- --emp-showcase` selects the repeatable EMP scene.
  Weapon (41) and landing (31) checks pass; the full forest suite passes 2,730
  checks with 72/72 finishers. Three-view EMP captures measured 1.377 ms total
  view GPU time in the city at 960 × 540 per view, and 1.198 ms in the Mobile
  forest renderer at 640 × 360 per view, both on the desktop RTX 5070 Ti.
  These are whole-scene GPU measurements, not tablet frame rates or isolated
  EMP overhead; parallel CPU simulations affected frame-time measurements.
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
