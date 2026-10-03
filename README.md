# Ion Rush

A small, original, F-Zero GX-inspired hover racer for GameNight. Godot 4.5.2;
native 3D with 1–4 local split-screen players. No external art or online services.
This is a playable prototype, not an exact recreation of GX physics.

## Play

Open `project.godot` in Godot 4.5.2 and press F6/F5, or run:

```sh
godot --path games/ion-rush
```

The portable Windows build runs by opening `IonRush.exe`. Start starts a race; the left stick navigates and A selects menu buttons. Enter also starts;
choose the player count on the title screen (or F2). Standalone races have six
machines, filling spare positions with AI. Escape/Back opens the menu; F5 starts
a fresh track. Three laps by default. Results last eight seconds, then a new
seeded track starts automatically.

The title screen keeps player selection and Race upfront; Controls expands the
driving reference. The race HUD uses compact corner readouts and a thin energy
bar. A small route map appears in single-player; split-screen keeps that space clear.

| Action | Controller | Keyboard P1 | Keyboard P2 |
|---|---|---|---|
| Steer | Left stick / D-pad | A / D | Left / Right |
| Accelerate | A / RT | W | Up |
| Brake / slide | LT (analog; X also brakes) | S | Down |
| Boost | B | Space | Ctrl |
| Strafe | Right stick left / right, or LB / RB | Q / E | Comma / Period |
| Grip / speed trim | Right stick forward / backward | Controller only | Controller only |

Keyboard P3: IJKL, U boost, Y/O strafe. P4: TFGH, R boost, V/B strafe.
Standalone assigns connected controllers once at race start; unplugging a
controller does not reassign the remaining players. Keyboard controls also work.

## Driving

Simulation runs at 120 Hz. LT is an analog brake: squeezing it slows the craft,
reduces magnetic grip and increases yaw authority. The hull turns ahead of its
momentum, so the craft slides outward. Brake before a sharp corner, turn into it,
then release LT and countersteer to catch the slide. Grip returns progressively.
LB/RB and the right stick's horizontal axis strafe without steering the nose.

Right stick forward lowers the nose and adds grip/downforce at the expense of
speed. Pulling back raises the nose; a partial pull trades grip for speed. Holding
full back at racing speed launches into independent world-space flight, even on
flat road. Crests can also break adhesion when downforce is low.

In flight, right stick forward/back pitches down/up, left stick banks and turns,
and right stick horizontal input adds air strafe. LT acts as an air brake. Gravity,
wing lift, angle of attack and stall loss affect velocity separately from attitude.
Approach the track from above, line up with its direction and banking, and touch
down without excessive descent speed to reconnect. Missing the road, a hard or
misaligned impact, hitting its underside, falling below the world, or remaining
in the air for ten seconds causes a two-second respawn at the takeoff position.
Progress is awarded when landing, so simply flying past the finish does not win.

Hinged wing elevons and twin tail rudders respond directly to pitch, steering,
strafing and braking, including during the starting countdown. Input deflection
is immediate; the hull and momentum retain their physical response time.
Sound is temporarily disabled for playtesting, including managed pause/resume.

Cruising speed is roughly 950 km/h; boost reaches roughly 1,400 km/h. Boost
unlocks on lap two, costs 22 energy, and lasts 1.25 seconds. Release and press
again to retrigger. Wall impacts also consume energy. Green lanes repair;
amber chevrons give a free boost. Empty energy triggers a two-second recovery
instead of eliminating a player from a couch session. Rotated hull-sized contact
boxes separate wings and noses, transfer impact speed, and keep crowded packs
inside the rails. Six machines start in two rows of three.

Seeded closed circuits combine broad sweepers, localized tight corner complexes,
large climbs and skyline dives, and one or two vertical corkscrew loops. The loop
crossings are separated laterally; magnetic grip carries the craft through the
inverted portion. Track frames, steering, hover height and the chase camera all
use the same 3D ribbon orientation. Width, banking and four color themes vary by
seed, with tunnels, recharge lanes and boost strips. Sharper corner complexes have amber edge braking markers ahead of their apexes.
There is no online/LAN multiplayer in this version.

The visual pass adds a banded ringed planet, star and aurora skies, two-tone city
windows, colored mesa strata, water far below the circuit, rotating reactor rings
and ambient flying traffic. Ships have beveled hulls, swept wings, cockpit glass
and animated tapered plasma jets, bright engine cores, and instanced exhaust
streaks. Exhaust responds to throttle and grows during boost. Road panels, metallic shading, shoulder
chevrons and animated energy strips help communicate speed and curvature.
Animated scenery and shader motion freeze with the GameNight pause state.

Six giant zoo animals overlook the circuit: golden giraffes, blue elephants with
curled trunks, and pink flamingos on terraced islands. Colored mesh details and
slow head movement make them visible landmarks. Placement keeps their silhouettes
clear of the track and shifts nearby buildings away from the islands. Their bodies
and heads each use a single colored mesh, without skeletal rigs or extra lights.

## Graphics and performance

The OpenGL Compatibility renderer is the baseline. Static track chunks are
frustum-culled; city blocks and distant mountains use MultiMesh instances. All
views share one world and simulation. One directional light, procedural sky and
road/window shaders, and emissive trim avoid expensive dynamic shadow maps.
Traffic and the city/rock layers are instanced; the small reactor meshes rotate
without rebuilding geometry. The 3D loop geometry is generated once per race.

Performance / Balanced / High change the 3D render scale to 60% / 80% / 100%.
High is the default and renders at native window/display resolution, including
fullscreen. Balanced and High use 2x MSAA. HUD stays at window resolution.
Split-screen divides a fixed total pixel budget between cameras. The UI
logical canvas is 1600×900; the actual 3D target follows output pixels, capped at 120 fps. This favors clear silhouettes and
readable track edges at high speed; it is intentionally stylized rather than
photorealistic. Profile target hardware before promising 4K or low-end frame rates.

Reproduce a render and collect actual wall-clock frame timings:

```sh
godot --path games/ion-rush -- --demo --players=4 --seed=145 --capture=/absolute/path/four.png --capture-frame=1800
```

For reproducible visual QA, add `--preview-u=.145` to start a demo near the first
loop entrance, `.211` for the inverted section, or `.49` for a skyline dive.
This flag only affects standalone demo mode; it does not skip progress in normal
or managed races. Short captures show layout; use longer runs for frame timings.

## GameNight

Game id: `ion-rush`. `src/bridge.gd` subclasses the vendored repository Godot SDK
transport (`addons/gamenight/gamenight.gd`) and adapts it to the current contract.
The old SDK's automatic screen helper and local controller enumeration are not
used. Managed games consume opaque controller tokens from `controller_frame`;
missing or 250 ms stale input becomes neutral. Empty seats create no craft;
AI seats use bots. No online network race synchronization is implemented.

Prepare builds the world and renders two warm frames off-screen before Ready.
Start/Resume explicitly show the borderless window. Pause freezes the race,
countdown, results, cameras, and audio; focus changes never start or resume it.
Back requires a full second of release between requests. Dispose frees the
world, and host disconnect exits. Round results report Finished and continue
within the same session. Live player names, colors, skin, and face artwork are
preserved by ID. Roster changes take effect on the next race; instant join is
false. `laps` applies next race and `quality` applies immediately.

The packaging tool emits a `shelf.json` with absolute local launch paths. Merge
that entry into your local GameNight shelf; no public catalog release or
certification is claimed. Managed launch arguments include `--position
-20000,-20000` to prevent a visible window at process startup.

```sh
python games/ion-rush/tools/package.py --godot /path/to/Godot.exe --output /new/output/directory
```

The portable development package includes the official Godot editor executable
as a runtime plus the game PCK, so no export templates are needed. For smaller
release builds install Godot export templates and export the provided Windows
Desktop preset. Code and geometric artwork are original, under the repository's
MIT license. Godot's license and bundled dependency notices are in `third_party`.

## Verification

```sh
godot --headless --path games/ion-rush --script res://tests/run.gd
python games/ion-rush/tests/integration.py --godot /path/to/Godot_console.exe --headless
python games/ion-rush/tests/integration.py --godot /path/to/Godot_console.exe
```

The simulation suite checks seeded track seams, full 3D frame continuity, inverted
hover height, crossing clearance, elevation range, acceleration, braking,
drift response, energy, boost gating, recovery, lap results, 12 full AI races,
and host input routing. The synthetic host test launches a real game process
and checks authenticated WebSocket lifecycle, hidden preparation, sparse/reversed
controller ownership, frozen pause, profiles, stale input, Back gating, repeated
Prepare/Dispose, and disconnect cleanup. These checks do not replace physical
controller or cross-platform focus testing. Test probes are opt-in via
`ION_PROBE_PATH` and are inactive in normal play.
