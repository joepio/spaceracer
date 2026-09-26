# Handling and difficulty playtest — 2026-09-26

Hard compresses the two sharp corner complexes to 62% and 70% of their Normal
width in the generator. Sampled seeds 6, 31, 145 and 421 have peak curvature
0.024–0.033 per metre, versus 0.012–0.018 on Normal. A paired physics test on
seed 31 uses identical steering: full throttle leaves the technical corner;
allowing anticipatory braking completes it without damage. This checks actual
driving consequences, not just the shape of the spline.

Hard's two flight gaps have 34- and 46-metre lateral landing offsets, alternating
direction by seed, with smaller landing margins than Normal. Aim for the cyan
landing markers. Across 44 seeds, the guided pilot lands every Normal and Hard
jump; the tests also verify that airborne travel awards no progress until a legal
touchdown. In four sampled Hard seeds, 34.4–35.4% of all road nodes are unguarded
(air gaps do not count as unguarded road in that numerator).

Bank targets are capped at roughly 11/16/19 degrees for Easy/Normal/Hard and
smoothed over about 220 metres. Secondary elevation waves are smaller and less
frequent. Vertical loops retain their full rotation. Existing seed codes remain
deterministic within this build; layouts differ from older versions.

Left-stick horizontal controls yaw and rudders; right-stick horizontal controls
roll and ailerons. Right-stick vertical still controls pitch. Flight body rates
respond strongly within 50 ms, with more sideslip damping, and sustained airspeed
is capped at 235 m/s versus the 265 m/s road cruise target. Faster takeoff momentum
decays at 70 m/s per second rather than snapping to the airspeed limit.

Airborne scenery collision uses swept expanded boxes in a 128-metre spatial
hash, plus moving traffic boxes. It follows individual building volumes and
solid tree branches, with conservative bounds for octagonal towers and roots;
it is not per-triangle collision. Crashes show a bounded fire/debris effect and
smoke until Y is pressed. Recovery costs 25 energy once and two seconds, returns
to safe road, and does not advance progress. Wrecks are excluded from on-road
vehicle contacts. Start opens a pause menu; Back no longer does.

The facade flicker had two contributors: coplanar faces in several building
recipes, and interpolated instance colors crossing discrete shader style/UV
thresholds. Inset/stepped volumes and flat interpolation of instance attributes
remove those artifacts. A native 1920×1080 close-up collision render was inspected
before and after; window textures now remain coherent behind the wreck.

## Verification

- Core simulation: 196,078 checks, 48/48 full-race finishers.
- Flight: 54 checks; scenery/crash/difficulty regression: 35 checks.
- Jumps: 18,058 checks, 44 seeds across all difficulty levels.
- Forest: 2,339 checks, 72/72 race finishers; city layout: 17,267 checks.
- Feature geometry: 8,373 checks; effects: 25; speed presentation: 612.
- Controller menu/pause tests, native crash/explosion render, and packaged
  GameNight integration are part of the release check.

Four-player Forest/Hard moving benchmark, seed 31, 1920×1080 total output
(four 960×540 views), RTX 5070 Ti / Ryzen 9 5900X, 1,200 sampled frames:
GPU mean **4.38 ms**, GPU p95 **4.91 ms**; wall mean **16.68 ms**, wall p95
**19.73 ms**. Background runner jobs were left active. These are observed frame
times under contention, not an isolated CPU benchmark or a universal FPS promise.

## Jump fixture collision correction

The full-world jump regression found a gap in the physics-only jump tests:
automatic scenery registration included the metal deck end caps and flush runway
stripes. Expanding these boxes by the craft collision radius made them project
above hover height, so every takeoff hit an invisible wall. Those pieces now use
the existing track surface/lip collision logic; upright beacons and other solid
scenery still collide. The full-world test on seed 31 changed from 36 failed
landings to 36 successful landings (six-craft packs, Normal and Hard, City and
Forest), with 40 checks passing. The separate scenery crash tests still pass.

## Crash breakup and camera

The intact craft is hidden on impact. Sixteen prebuilt fragments use the actual
hull, canopy, nacelle, wing, elevon, rudder, nozzle and airbrake geometry; the hull
is split into three sealed sections. A bounded 60 Hz fragment simulation carries
impact momentum, integrates gravity and spin, applies restitution/friction on
swept scenery contacts and road contact, and sleeps settled pieces. It uses
approximate fragment collision volumes, without fragment-to-fragment contacts.
The particles and fragments share the pausable race clock. Geometry is pooled
at world creation, so repeated crashes do not allocate fresh meshes.

Crash input is locked at the simulation and fin-animation layers. Y and pause
still work; recovery hides the fragments and restores the original craft. The
camera carries its recent velocity into a damped stop, eases aim independently
of fragment roll, avoids scenery and eases away from rebounding debris.

The 47-check wreck regression covers uncontrolled tumbling, road settling,
scenery bounce normals, identical motion under neutral versus saturated inputs,
paused visuals/camera, bounded camera coast and recovery. The 40 full-world jump
checks and 612 speed-camera checks also pass. Native 1080p building-impact frames
were inspected at the initial flash, breakup and falling-debris stages.

A six-simultaneous-crash CPU probe (Forest/Hard 31, 360 ticks, active background
jobs and playtest) measured about 3.2 ms to activate all six pooled wrecks, versus
39.9 ms when their meshes were allocated at impact. The combined simulation and
visual updates averaged 4.44 ms per 120 Hz tick, p95 12.42 ms; fragment simulation
runs on every second tick. This is a worst-case CPU probe, not rendered frame time.

## Airspeed-dependent lift and unrestricted low-speed turns

Wing lift now fades between 75 and 155 m/s of forward airspeed, with less inherent
lift below cruise speed. Angle of attack still adds lift before the existing stall
limit. Maximum thrust is below gravity, so pointing vertically up cannot hover.
At 60 m/s with neutral pitch and no throttle, the isolated simulation drops 22.3 m
in one second. At 235 m/s with full throttle it drops only 0.06 m. Starting at
130 m/s, full throttle with a 22-degree nose-up attitude gains about 1 m, versus
losing 14.5 m with level pitch. Releasing throttle eventually costs speed and lift.

Ground yaw has no hard angle clamp. Alignment assistance fades out below 35 m/s
and reaches its normal strength at 130 m/s, letting stationary craft rotate freely
and hold their chosen heading. Wrapped angles remain continuous through full turns.
Track progress and strafe use actual facing rather than a minimum forward-speed
factor, and contact impulses account for opposite-facing vehicles.

The 15-check airspeed/turning regression covers gravity, power/pitch recovery,
stalling, two stationary rotations in both directions, released-stick heading,
reverse/sideways travel and head-on contacts. The 54 flight checks, 18,058 jump
checks across 44 seeds, and 196,078 core simulation checks pass (48/48 finishers).


## Direct jet flight turns

Pitch and yaw now rotate the travel vector alongside the craft at flying speed.
The turn assistance preserves speed rather than adding thrust, and fades with
forward airspeed (80–180 m/s) and poor nose/airflow alignment. Roll continues to
bank the wings independently. Existing gravity, aerodynamic lift, drag, engine
power and the lower flight speed limit still apply. Launch keeps its measured
velocity and attitude without a snap.

At 235 m/s, a one-second full pull-up previously turned travel only 14.7 degrees,
leaving 84.5 degrees between the nose and movement. It now turns travel 99.8
degrees with 0.5 degrees of lag. Full yaw improves from 61.6 to 89.7 degrees,
with lag reduced from 27.8 to 1.3 degrees. These are isolated 120 Hz simulations.
The jet-turn regression also checks 30/60 Hz behavior, banked pitch, releasing
controls, retained speed, and low-speed falling. Bots aim through the hover plane
on landing so the more direct response does not leave them skimming above it.
