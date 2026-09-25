# Flight sections and course difficulty

The menu, command line and GameNight settings now select Easy, Normal or Hard.
A replay is identified by the five-digit seed **and** difficulty within this
game version. Changing difficulty in GameNight takes effect on the next race.

Easy adds nine metres to each side of the base road, broadens the sharp corner
complexes, uses a shallower half-pipe and protects open edges. It has no mandatory
flight gaps. Players can still deliberately pull back into free flight.
Normal adds one short gap and a landing deck widened by up to eighteen metres
per side. Hard lengthens that gap, adds a second flight section near the end of
the lap and widens landing decks by only eight metres per side.

Run-up and landing positions are seeded. Amber bars/beacons mark takeoff; cyan
ones mark touchdown. The road mesh actually stops at each lip, and support
queries reject every lateral position in the gap. Geometry and physics share
the same node-aligned boundaries. Liftoff preserves measured surface velocity,
attitude and the existing vehicle-following camera. Airborne distance does not
advance race progress until a legal landing. Failed jumps return to a solid
run-up 260 metres before the lip, without awarding skipped distance.

Landing decks allow normal descent up to 100 m/s, versus 75 m/s for ordinary
road. Firm touchdowns lose up to 18% speed and six energy; nose alignment,
upright orientation and forward approach are still required. Inverted, overly
steep and underside impacts crash. Swept landing detection compares both ends
of the movement against their local surfaces, including a rising landing deck.
The AI uses the same fighter physics, anticipates the landing, flares and air
brakes. Its boost decisions leave a safe run-up before mandatory gaps.

City lots and ambient traffic reserve additional clearance beside and above
the flight corridor. No extra dynamic lights or per-frame mesh generation were
introduced for the runway markers.

## Validation, September 25, 2026

- 44 seeds at all three settings: 21,867 checks; all 132 mandatory jump/flight
  cases landed. Includes exact replay, release continuity, unsupported gaps,
  landing penalties, excessive-descent rejection and safe respawn checks.
- Twelve full six-racer, three-lap races: 72/72 finishers. Easy had zero launches,
  Normal had 18 per race and Hard 36. Longest race was approximately 113 seconds.
- Existing core geometry/handling suite: 196,893 checks; 48/48 AI finishers.
- Flight 43, track features 8,412, city 17,430, lighting 60 and effects 25 checks
  passed. Menu navigation verifies analog/A/Start, seed preservation and the
  selected difficulty. Native screenshots cover both Hard flight sections.
- GameNight source and packaged native integration passed: difficulty applies next race, along with
  authentication, sparse controller ownership, pause/resume, profile updates,
  dispose/reprepare and disconnect cleanup.

Headless menu/lighting test shutdown can emit an AudioStreamWAV playback cleanup
warning; verbose inspection identifies the audio resource, not road geometry.

## Four-player rendering measurement

RTX 5070 Ti, Godot 4.5.2 Forward+, 1920×1080 High, four 960×540 views. Seed 00031,
Hard, moving AI race beginning 90 metres before the first jump, five-second
warm-up and 1,200 measured frames; VSync/frame cap disabled by the harness.

| Metric | Result |
|---|---:|
| Mean measured viewport GPU time | 1.407 ms |
| GPU p95 | 1.603 ms |
| Wall-frame mean | 5.817 ms |
| Wall-frame p95 | 8.542 ms |
| Render CPU mean | 2.166 ms |
| Mean system CPU during sampling | 25.3% |

The old playtest was closed for this measurement. GitHub runners and a Rust
build were left running. This is one moving sample, not a guaranteed frame rate
or a controlled before/after comparison. Raw JSON/CSV, telemetry and the final
frame are in `C:/dev/ion-rush-captures/lighting/flight-difficulty-moving-4.*`.
The screenshot harness writes to `C:/dev/ion-rush-captures/flight-difficulty/`.
