# Ion Rush

A small, original, F-Zero GX-inspired hover racer for GameNight. Godot 4.5.2;
native 3D with 1–4 local split-screen players. Bundled AI-generated city textures; no online services required.
This is a playable prototype, not an exact recreation of GX physics.

## Repository

This is a self-contained Godot project: source, procedural geometry and bundled artwork, the vendored
GameNight transport, tests and packaging tools are included. It does not need a
GameNight checkout to build or run. Development requires Godot 4.5.2; Python 3.12+
with only its standard library runs the packaging and integration tools.

## Play

Open `project.godot` in Godot 4.5.2 and press F6/F5, or run:

```sh
godot --path .
```

The portable Windows build runs by opening `IonRush.exe`. Start starts a race; the left stick navigates and A selects menu buttons. Enter also starts;
choose the player count on the title screen (or F2). Standalone races have six
machines, filling spare positions with AI. Start/Escape pauses with Resume,
Restart race and Track settings; Back no longer pauses. F5 starts
a fresh track. Three laps by default. Results last eight seconds, then a new
seeded track starts automatically.

The start menu has a five-digit **Track seed** (00001–99999). Type a code or select
**Random** with the controller to choose another. Race uses that exact code;
it remains visible in the HUD and results so you can write it down. Returning
to the menu keeps the current code for replay. Seeds reproduce the track and
scenery within the same game version. Write down the difficulty and world with
the code; both appear beside the seed in the HUD and results.

**World** switches between the neon **City** and **Forest — Verdant Reach**.
The forest has a bright blue daytime sky, soft procedural clouds and warm sunlight.
It races over a reflective lake among 260–520 metre trees, branching
canopies, mossy islands and thousands of ferns. Lower hills bring portions of the
course nearer the water, while the loops and difficulty-dependent flight gaps
remain. Foliage and ripples follow the race clock; hitting the water crashes the
craft and waits for Y to reset. Geometry is procedural and instanced; no asset downloads are needed.
Selecting a world updates the menu preview without changing the chosen seed.
GameNight exposes **World (next race)**, and standalone accepts `--biome=forest`
or `--biome=city` after `--`.

Choose **Level** with A/click in the start menu:

- **Easy:** wider road, gentler sharp corners, protected edges and no mandatory
  flight gaps. The half-pipe is shallower. Deliberate pull-back takeoff still works.
- **Normal:** exposed sky sections and pipe edges, a short jump, and a wide landing.
- **Hard:** much tighter braking corners, sparser guardrails, and two longer gaps
  with narrow landing decks displaced sideways. Aim in flight to reach them;
  holding straight ahead misses the landing. About a third of the road is unguarded.

Every seed includes a half-pipe, a full magnetic tube and a fork with two separate
decks that rejoin. Feature placement and size
vary with the seed. Steer/strafe up the pipe walls and around the tube ceiling;
return toward the bottom as the tube opens out. Running past an unguarded edge
enters free flight, with the existing landing/respawn rules. Pick a side before
the fork; both routes use the same lap progress and merge back into one road.

Guarded sections have 2.5-metre sidewalls with luminous top edges. Mounted amber
chevrons on the outside of tighter corners indicate the first significant turn
up to 320 metres ahead. Intentional open edges and flight gaps remain open.

Amber runway bars mark launch ramps; cyan bars and beacons mark the landing deck.
Keep speed through the run-up. Crossing the lip releases into the same fighter
flight controls as manual takeoff, carrying velocity and attitude without a kick
or camera switch. Pitch, roll and yaw to line up with the landing. The gap has no
road surface or hidden collision bridge. Purpose-built landing decks absorb a
firm touchdown with a speed/energy penalty; steep or misaligned impacts crash.
After a missed jump, Y resets 260 metres before the lip, leaving room to accelerate again.
Buildings and ambient traffic leave an expanded corridor around these sections.

The same difficulty is available as a GameNight **Track difficulty (next race)**
setting, or `--difficulty=easy|normal|hard` after Godot's `--` argument separator.

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
| Reset when airborne or crashed | Y | 1 | 2 |
| Pause / resume | Start | Escape | Escape |

Keyboard P3: IJKL, U boost, Y/O strafe. P4: TFGH, R boost, V/B strafe.
Keyboard recovery uses 3 for P3 and 4 for P4.
Standalone assigns connected controllers once at race start; unplugging a
controller does not reassign the remaining players. Keyboard controls also work.

## Driving

Simulation runs at 120 Hz. LT is an analog brake: squeezing it slows the craft,
reduces magnetic grip and increases yaw authority. The hull turns ahead of its
momentum, so the craft slides outward. Brake before a sharp corner, turn into it,
then release LT and countersteer to catch the slide. A short brake tap breaks
adhesion quickly and leaves a slide after release; the nose responds faster than
the lateral momentum. Grip returns slowly, with forward trim and countersteering
helping catch the slide. Dorsal airbrakes open and orange forward-facing reverse
jets fire with brake pressure; a brief visual decay keeps short taps readable.
LB/RB and the right stick's horizontal axis strafe without steering the nose.
At low speed, left-stick steering can rotate the craft through full circles and
holds its heading when released. Track alignment assistance fades in with speed;
there is no hard heading clamp. Thrust and strafing follow the craft's facing,
including sideways and backwards movement, without artificial forward progress.

Right stick forward lowers the nose and adds grip/downforce at the expense of
speed. Pulling back raises the nose; a partial pull trades grip for speed. Holding
full back at racing speed progressively unloads the magnetic suspension. The
craft rises, its wings buffet gently, and a “Lifting” cue appears before release.
Ease the stick forward during this warning to settle back down. Sustained back
input releases into independent flight, carrying the actual track velocity and
attitude through takeoff with no added kick. Crests can also unload adhesion.

In flight, right stick forward/back pitches down/up, left stick left/right controls
yaw through the rudders, and right stick left/right (or LB/RB) rolls via the wing
ailerons. The same fin mapping is visible while driving. These are
independent body-axis controls: roll sets bank, with no forced levelling or hidden
yaw. Bank and pull back to turn like a fighter. LT acts as an air brake. Angular
rates build and stop quickly with stick input; wing lift, bank, angle of attack,
side-slip and gravity bend the flight path rather than instantly redirecting it.
Lift falls sharply at low forward airspeed. Slow flight sinks under gravity;
use throttle to regain speed and a moderate nose-up attitude to arrest the sink.
Pulling too far still stalls, and even full throttle cannot hover vertically.
Fast powered flight can remain nearly level. Control surfaces show pitch, roll and yaw.
Sustained flight tops out at 846 km/h, below the 954 km/h road cruise speed.
Extra launch momentum decays smoothly instead of disappearing at takeoff.

One vehicle-relative chase camera follows road, lift-off, flight and touchdown.
Its orientation, chase distance and field of view ease continuously; its anchor
moves with the craft so smoothing does not leave the camera behind at high speed.
Acceleration briefly pulls the lens wider, then settles at cruise. Boost builds
to a wider lens, stronger peripheral motion blur and subtle camera vibration.
The floating speed motes have been removed. A subtle peripheral shade under boost
complements the lens surge and blur, leaving the ship, racing line and HUD clear.
Each split-screen view responds only to its own craft. Performance graphics
disable blur; pause freezes the effects clock.
Approach the track from above, line up with its direction and banking, and touch
down without excessive descent speed to reconnect. Missing the road, a hard or
misaligned impact, hitting its underside, falling below the world, or remaining
in the air for ten seconds crashes the craft. Buildings, solid tree parts,
islands, traffic and track fixtures can also be hit while flying. A crash produces
an explosion that breaks the craft into 16 hull, wing, engine and tail pieces.
They carry impact momentum, tumble under gravity, bounce off scenery and the road,
then settle. Steering, throttle, braking and movable fins are disabled until
recovery; **Y to reset** and pause remain available. The camera coasts briefly,
eases its aim toward the debris and keeps some distance from rebounding parts.
Y also initiates recovery while airborne: two seconds of downtime, loss of
momentum and up to 25 energy (leaving at least one). A crash already charges the
energy cost; resetting the wreck does not charge it twice. Recovery
returns to the last safe track position, before a mandatory jump when applicable,
without awarding progress. Holding Y cannot trigger repeated resets. Manual
recovery does not refill energy.
Progress is awarded when landing, so simply flying past the finish does not win.

Hinged wing elevons and twin tail rudders respond directly to pitch, steering,
strafing and braking, including during the starting countdown. Input deflection
is immediate; the hull and momentum retain their physical response time.
During the countdown, craft rest level near the deck until RT / A (or keyboard
throttle) starts their engines. One side rises first, then the other, settling into
hover. Engine sockets brighten and develop soft blue-white halos with throttle,
even while the starting grid remains locked. This startup is cosmetic: pressing
throttle exactly at GO has the same acceleration as warming up beforehand.
Sound is temporarily disabled for playtesting, including managed pause/resume.

Cruising speed is roughly 950 km/h; boost reaches roughly 1,400 km/h. Boost
unlocks on lap two, costs 22 energy, and lasts 1.25 seconds. Release and press
again to retrigger. Wall impacts also consume energy. Green lanes repair;
amber chevrons give a free boost. Empty energy crashes the craft; Y starts its
two-second recovery. Rotated hull-sized contact
boxes separate wings and noses, transfer impact speed, and keep crowded packs
inside the rails. Six machines start in two rows of three.

Seeded closed circuits combine broad sweepers, localized tight corner complexes,
large climbs and skyline dives, and one or two vertical corkscrew loops. The loop
crossings are separated laterally; magnetic grip carries the craft through the
inverted portion. Track frames, steering, hover height and the chase camera all
use the same 3D ribbon orientation. Width, banking and four color themes vary by
seed, with tunnels, recharge lanes and boost strips. Banking eases across long
transitions, with smaller angles and fewer secondary humps. Sharper corner
complexes have amber edge braking markers ahead of their apexes.
There is no online/LAN multiplayer in this version.

The circuit now runs through one coherent neon city: more than 1,000 seeded
buildings form dense streets and elevated racing canyons. Eight architectural
families include twin residential towers, stepped terraces, octagonal glass
skyscrapers, offset office volumes, podium towers, narrow spires, broad offices
and L-shaped blocks. Six roof styles add penthouses, equipment and antenna clusters.
Different window bands, warm offices and occasional neon break up repetition.
Distant windows fade into the night haze to keep the racing surface readable.

Large advertisements are mounted directly on buildings; floating text boards
have been removed. Around 180–200 flying cars travel along reserved aerial lanes between city blocks, with
separate hulls, canopies and bright engine trails. The enclosed expressway tunnel
follows the banked track, with chasing cyan/magenta strips and a few shadow-free
colored lights that illuminate the craft. The planets, mesas, reactor rings,
water backdrop and giant animals have been removed from the active environment.

Every building reserves its full envelope, including roofs and antennas, against
a conservative swept volume around every road segment. This includes banking,
vertical loops, crossings and camera clearance. Mounted screens stay inside their building envelopes. Full traffic routes also
clear the road and buildings. The opening skyline preserves views of the loop.

Ships have beveled hulls, swept wings, cockpit glass and animated tapered plasma
jets, bright engine cores, and instanced exhaust streaks. The engine socket glow
responds to throttle; plume length grows with actual acceleration and boost.
Exhaust sparks move backward relative to the craft at vehicle speed plus
220–380 m/s (another 220 m/s during boost), with short exposure streaks. Their
distance is integrated from the effects clock, so throttle changes cannot jump
the trail and pausing freezes it. The particle count remains fixed at 20 per craft.
Each craft has two short-range dynamic exhaust lights, one per nozzle. Throttle and boost
illuminate its hull, the road and nearby racers, including during countdown; the
lights follow free flight, track live player colors and turn off during recovery. They are shared across
views and use no shadow maps.
HDR bloom complements the localized engine halos in Forward+. The OpenGL fallback
retains the local halos. Road panels, metallic shading,
shoulder chevrons and animated energy strips communicate speed and curvature.
All city traffic, tunnel lighting and effects freeze with GameNight pause.

## Graphics and performance

Forward+ is the default renderer, with screen-space reflections, restrained HDR
bloom and ambient occlusion. A Vulkan-capable GPU is recommended. For the lighter
OpenGL fallback, launch `IonRush.exe --rendering-method gl_compatibility`.

The opening district attempts to place six large advertising towers beside the seeded
track, with mechanical floors, metal mullions and visible streetlights. Three
static reflection probes capture the city once per race and are shared across
all views. Ship paint uses clearcoat, fine panel seams and narrow hull bevels;
machined nozzle rims surround the exhaust sockets. Every road chunk chooses four
nearby mounted billboards and intersects their real planes along the reflected
view ray. The opening 16% also samples up to 24 nearby box-shaped building parts,
using the same facade texture, window occupancy and warm/neutral colors as the
visible buildings. This preserves window and artwork reflections outside the
screen, at a fixed per-pixel cost. Small rooftop details, octagonal towers and
other unselected geometry are omitted; these are bounded software reflections,
not hardware ray tracing or complete scene occlusion. Selection can change at
chunk boundaries. Probes supply broader surroundings and screen-space reflections
add visible geometry. Water-film normals break up the reflected images.

Streetlights aim at the road from visible fixtures. At most two nearby fixture or
billboard lights per player cast shadows (eight total for four players, fewer
when views share lights). Shadow selection updates at most every 0.15 seconds;
distance fades and 1024/2048 shadow atlases bound the cost. Exhaust and tunnel
lights remain shadow-free. High adds a short, subtle volumetric haze; Balanced
omits it. Screen-space indirect lighting was measured and disabled because its
contribution to this scene was negligible. These are local lighting effects,
not full-scene global illumination.

Static track chunks are
frustum-culled; city architecture uses spatially grouped MultiMesh instances. All
views share one world and simulation. A faint, non-specular night fill, a handful of short-range shadow-free tunnel lights,
procedural sky, road shading and instanced textured facades keep lighting inexpensive. Buildings and
traffic are instanced; only car transforms and lighting/effect parameters change each frame.
City lots, the enclosed tunnel and 3D loop geometry are generated once per race.

Performance / Balanced / High change the 3D render scale to 60% / 80% / 100%.
High is the default and renders at native window/display resolution, including
fullscreen. Balanced and High use 2x MSAA, bloom and screen-space reflections; High also uses
ambient occlusion and volumetric haze. Reflection ray steps drop from 48 to 32 in split-screen.
Performance disables these screen-space effects and local shadows. HUD stays at window resolution.
Split-screen divides a fixed total pixel budget between cameras. The UI
logical canvas is 1600×900; the actual 3D target follows output pixels, capped at 120 fps. This favors clear silhouettes and
readable track edges at high speed; it is intentionally stylized rather than
photorealistic. Profile target hardware before promising 4K or low-end frame rates.

Reproduce a render and collect actual wall-clock frame timings:

```sh
godot --path . -- --demo --players=4 --seed=145 --capture=/absolute/path/four.png --capture-frame=1800
```

For reproducible visual QA, add `--preview-u=.145` to start a demo near the first
loop entrance, `.211` for the inverted section, or `.49` for a skyline dive.
This flag only affects standalone demo mode; it does not skip progress in normal
or managed races. Short captures show layout; use longer runs for frame timings.

## GameNight

Game id: `ion-rush`. `src/bridge.gd` subclasses the vendored GameNight Godot SDK
transport (`addons/gamenight/gamenight.gd`) and adapts it to the current contract.
The old SDK's automatic screen helper and local controller enumeration are not
used. Managed games consume opaque controller tokens from `controller_frame`;
missing or 250 ms stale input becomes neutral. Empty seats create no craft;
AI seats use bots. No online network race synchronization is implemented.

Prepare builds the world and renders two warm frames off-screen before Ready.
Start/Resume explicitly show the borderless window. Pause freezes the race,
countdown, results, cameras, and audio; focus changes never start or resume it.
Start requires a full second of release between requests. Dispose frees the
world, and host disconnect exits. Round results report Finished and continue
within the same session. Live player names, colors, skin, and face artwork are
preserved by ID. Roster changes take effect on the next race; instant join is
false. `laps`, `difficulty` and `biome` apply next race and `quality` applies immediately.

The packaging tool emits a `shelf.json` with absolute local launch paths. Merge
that entry into your local GameNight shelf; no public catalog release or
certification is claimed. Managed launch arguments include `--position
-20000,-20000` to prevent a visible window at process startup.

```sh
python tools/package.py --godot /path/to/Godot.exe --output build/windows
```

The portable development package includes the official Godot editor executable
as a runtime plus the game PCK, so no export templates are needed. For smaller
release builds install Godot export templates and export the provided Windows
Desktop preset. Code and geometric artwork are original, under this repository’s
[MIT license](LICENSE). Godot's license and bundled dependency notices are in `third_party`.

To launch through a local Windows GameNight host, point the daemon at the shelf
emitted for this build (keep that build directory in place):

```powershell
$env:GAMENIGHT_LIBRARY = (Resolve-Path ./build/windows/shelf.json).Path
& /path/to/gamenight-daemon.exe
```

If you already have a library, merge the Ion Rush object into its JSON array
instead of replacing the other entries. The daemon supplies the authenticated
launch environment; players and controllers are assigned in GameNight. Rebuild
to regenerate absolute paths after moving the package. For development with a
GameNight checkout, its `scripts/run-local.py --shelf <absolute shelf.json>` also
loads this game and the lobby together.

## Verification

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/run.gd
godot --headless --path . --script res://tests/flight.gd
godot --headless --path . --script res://tests/airspeed_turning.gd
godot --headless --path . --script res://tests/crashes.gd
godot --headless --path . --script res://tests/wrecks.gd
godot --headless --path . --script res://tests/menu.gd
godot --headless --path . --script res://tests/effects.gd
godot --headless --path . --script res://tests/city.gd
godot --headless --path . --script res://tests/lighting.gd
godot --headless --path . --script res://tests/track_features.gd
godot --headless --path . --script res://tests/jumps.gd
godot --headless --path . --script res://tests/world_jumps.gd
godot --headless --path . --script res://tests/difficulty_soak.gd
godot --headless --path . --script res://tests/speed_feel.gd
godot --headless --path . --script res://tests/forest.gd
python tests/integration.py --godot /path/to/Godot_console.exe --headless
python tests/integration.py --godot /path/to/Godot_console.exe
```

The simulation suite checks seeded track seams, full 3D frame continuity, inverted
hover height, crossing clearance, elevation range, acceleration, braking,
drift response, energy, boost gating, recovery, lap results, 12 full AI races,
and host input routing. The synthetic host test launches a real game process
and checks authenticated WebSocket lifecycle, hidden preparation, sparse/reversed
controller ownership, frozen pause, profiles, stale input, Start gating, repeated
Prepare/Dispose, and disconnect cleanup. These checks do not replace physical
controller or cross-platform focus testing. Test probes are opt-in via
`ION_PROBE_PATH` and are inactive in normal play.

## City rendering

The city uses a mipmapped AI-generated office facade with neutral/warm windows,
four large advertising artworks mounted on safe building lots, and wet-road
restrained rail reflections on charcoal asphalt, soft ambient lighting and a dark,
continuous horizon. Repair and boost zones use small inset markings. The road
reflections combine geometric window/billboard samples, static probes and
screen-space reflections; direct lights produce the moving specular highlights.
Balanced and High add a restrained five-tap peripheral speed blur to each view;
the ship area and HUD stay crisp. Performance disables blur. Split-screen keeps
the same total native pixel budget. Asset provenance and prompts: `assets/README.md`.

Eight building families span slender 24 m towers to 195 m office blocks, with
six rooftop styles: offset penthouses, paired blocks, stepped crowns, equipment
huts and antenna clusters. Different facade rhythms break up the repeated grid.
Building lots reserve the full roof and mast height and exclude one another as
well as the complete swept track corridor.

### Repeatable lighting measurements

`tests/lighting_bench.gd` freezes seed 00031 at the normal gameplay camera for
comparable screenshots. It warms for five seconds, disables VSync/the frame cap,
then records per-viewport GPU timestamps, rendering CPU time and wall intervals.
Screenshot readback is excluded. Use `--views=4` for split-screen or `--moving`
for simulated bot driving (which includes gameplay CPU work and motion blur).
The fixed-scene numbers are render costs, not advertised gameplay FPS.

```powershell
godot --path . --resolution 1920x1080 --script res://tests/lighting_bench.gd -- --out=C:/captures/ion-rush --label=solo --samples=1800
```

Other flags: `--quality=.8`, `--fraction=.055`, and
`--ablation=no-box-reflections|no-ssr|no-ssil|no-shadows|no-volumetrics|no-probes`.
Run one GPU test at a time; background CI/browser workloads affect CPU and wall
timing. See [the measured lighting review](docs/lighting-review.md).
