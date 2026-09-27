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

The portable Windows build runs by opening `IonRush.exe`. Start/Enter starts a race.
For local development, run `tools/install_start_menu.ps1` to install
**Ion Rush (Latest Debug)** in the Windows Start menu with the game's icon.
It opens fullscreen and points directly to `build/warp-balance/IonRush.exe`;
keep updating that directory's executable/PCK so the shortcut always opens the
latest packaged debug build. The installer also accepts `-BuildDirectory`.

The title and pause screens share the same menu: up/down selects a row; left/right
immediately adjusts players, world, level, seed or graphics. The stick, D-pad,
keyboard arrows and on-screen arrow buttons all work. A/click activates actions.
Standalone races have six machines, filling spare positions with AI.
Start/Escape pauses. Unchanged settings resume the current race; changing a race
setting changes the primary action to **Restart**. Graphics never resets progress.
The paused track stays frozen until resuming or restarting. Back no longer pauses.

Desktop Forward+ also has a **Lighting** row: **Direct** or experimental **SDFGI**.
Switch it in the pause menu to compare the same view without restarting the race.
SDFGI adds environmental bounce light and is opt-in; selecting it raises Performance
graphics to Balanced. Selecting Performance disables it again. Mobile keeps direct
lighting and does not show the unsupported option. `--sdfgi` enables the trial at
launch; `--direct-lighting` selects the fallback. See [the lighting experiment](docs/gi-experiment.md)
for measurements and limitations.
F5 starts a fresh track. Three laps by default; results last eight seconds.
After finishing, an autonomous victory lap keeps your ship moving while a replay
camera cycles through rear-quarter, front, side and overhead shots. Other players
keep racing with their own chase cameras. Finish times and places stay locked;
the camera and victory lap pause with the game and continue behind the results.

The start menu has a five-digit **Track seed** (00001–99999). Use left/right for the previous/next code, type a code, or select
**Random** with the controller to choose another. Race uses that exact code;
it remains visible in the HUD and results so you can write it down. Returning
to the menu keeps the current code for replay. Seeds reproduce the track and
scenery within the same game version. Write down the difficulty and world with
the code; both appear beside the seed in the HUD and results.

The seed also chooses a **track character**, shown beneath the code in both menus.
Try these examples in any world:

| Seed | Character | Racing rhythm |
| --- | --- | --- |
| 00031 | Grand Circuit | Mixed corners, loop, fork and pipes |
| 00032 | Underpass | Four long illuminated tunnels with daylight/open-air breaks |
| 00033 | Switchback | Repeated tight left/right chicanes and a narrow sector |
| 00034 | Sky Circus | Three loops, repeated jumps and an exposed skyway |
| 00035 | Velocity | Long true straights, broad end turns, narrows and a split |
| 00036 | Pipeline | Repeated half-pipes and enclosed magnetic tubes |

Other seeds vary the dimensions, hills, corner shapes and component sizes within
these families. Character is independent of scenery and difficulty. This generator
revision intentionally changes older layouts outside the Grand Circuit family;
sharing a seed requires the same game version. See [track generation notes](docs/track-identities.md).

**World** switches between the neon **City**, **Forest — Verdant Reach**, and **The Cell**.
The forest has a bright blue daytime sky, soft procedural clouds and warm sunlight.
It races through rolling grassy hills, wooded banks and connected lakes beneath a dense canopy dominated by 340–650 metre trees.
Authored pine and birch models replace the homemade tree generator. Random rotation,
subtle proportions, smaller 80–340 metre trees and more than 4,000
varied ferns break up repetition in the checked seeds. Trees and ferns are planted
on dry terrain. The seeded height field creates connected land, shallow banks and
submerged valleys; hills are carved below the full track and jump corridors.
Ground collisions and shoreline colors use the same surface as the visible mesh. Models come from the
[Godot Procedural Forest Demo](https://github.com/GamesNotDeveloped/godot-forest-demo):
**Pine Tree by evolveduk** and **Tree Bake Upload by restlessmonkey**, both CC BY 4.0.
Sources, original credits and license are in `third_party/forest-demo`; in-game
credits are under Controls & credits. Modified scale, materials and textures.
Imported meshes use Godot-generated LODs, spatial MultiMesh batches, compressed
mipmapped textures and depth-writing alpha cutouts. Lower ambient fill and
real directional shadows keep shaded sides dark, including on Android.
Water uses two scrolling ripple-normal samples, low swells and a seeded 512px
shoreline map for shallows, with existing sky/probe reflections and desktop SSR.
It needs no extra reflection camera or per-frame CPU water simulation. Lower hills bring portions of the
course nearer the water, while the loops and difficulty-dependent flight gaps
remain. Undergrowth and ripples follow the race clock; hitting the water crashes the
craft and respawns it automatically after two seconds. Placement is seeded and instanced; authored models are bundled for offline play.
Selecting a world updates the menu preview without changing the chosen seed.
**The Cell** races inside a teal membrane, among towering double-stranded DNA,
folded proteins, ribbed mitochondria, pleated membrane sheets, and a giant nucleus
with nuclear pores. Six-legged cargo organelles pace along microtubules, carrying
vesicles with alternating footfalls and a gently bobbing body. This is a stylized
microscopic world, not a biologically literal cell model. Coral, lilac and jade
tissue uses glossy shaded surfaces and a subtle luminous rim.
All geometry is generated locally and shared in spatial instance batches.
Scenery placement and entire walking envelopes avoid the track and jump corridors;
solid structures and moving bodies can be hit in free flight. Animation pauses
with the race. All three difficulties, seeds, weapons and split-screen modes work
in this setting too.

GameNight exposes **World (next race)**, and standalone accepts `--biome=forest`,
`--biome=city`, or `--biome=cell` after `--`.

Adjust **Level** with left/right in either menu:

- **Easy:** wider road, gentler sharp corners, protected edges and no mandatory
  flight gaps. The half-pipe is shallower. Deliberate pull-back takeoff still works.
- **Normal:** exposed sky sections and pipe edges where the recipe uses them,
  short jumps, and wider landings.
- **Hard:** much tighter braking corners, sparser guardrails, and longer gaps
  with narrow landing decks displaced sideways. Aim in flight to reach them;
  holding straight ahead misses the landing. The number of gaps and open edges
  depends on the track character.

Recipes choose from half-pipes, full magnetic tubes, forks with two separate
decks that rejoin, chicane complexes, smoothly narrowing decks, tunnels, loops and jumps.
Steer/strafe up the pipe walls and around the tube ceiling;
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
After a missed jump, recovery returns 260 metres before the lip, leaving room to accelerate again.
Buildings and ambient traffic leave an expanded corridor around these sections.

The same difficulty is available as a GameNight **Track difficulty (next race)**
setting, or `--difficulty=easy|normal|hard` after Godot's `--` argument separator.

The title screen keeps player selection and Race upfront; Controls expands the
driving reference. The race HUD projects through a curved, translucent helmet
visor: luminous corner instruments, a segmented energy arc, subtle optical halos
and a small flight attitude reference. A radar-style route map appears in
single-player; split-screen keeps that space clear. Instruments stay at output
resolution when 3D resolution is reduced. Missile brackets compensate for the
visor curvature to remain aligned with the targeted ship. The visor hides and
stops rendering while the shared start/pause menu is open.

| Action | Controller | Keyboard P1 | Keyboard P2 |
|---|---|---|---|
| Steer | Left stick / D-pad | A / D | Left / Right |
| Accelerate | A / RT | W | Up |
| Brake / slide | LT (analog) | S | Down |
| Boost | B | Space | Ctrl |
| Use pickup | X | X | Slash |
| Strafe / roll | Right stick left / right | — | — |
| Side bump | LB / RB | Q / E | Comma / Period |
| Grip / speed trim | Right stick forward / backward | Controller only | Controller only |
| Reset while airborne | Y | 1 | 2 |
| Pause / resume | Start | Escape | Escape |

Keyboard P3: IJKL, U boost, Y/O bump. P4: TFGH, R boost, V/B bump.
Keyboard recovery uses 3 for P3 and 4 for P4. Pickup use is P for P3 and C for P4.
Standalone assigns connected controllers at race start and fills disconnected seats when a controller is paired later. Other connected players keep their seats. Keyboard controls also work.

## Energy batteries

**Slipstream:** follow a moving rival closely to reduce drag and build extra speed
without spending energy. Stay directly behind them, ideally 20–45 metres back;
the wake fades out by 145 metres and outside its narrow corridor. Full drafting
reduces aerodynamic drag by 26%, bringing level-road full-throttle cruise from
about 954 to 1,109 km/h. It builds over half a second and fades when pulling out
to pass; braking remains fully effective. Boost gains a smaller 12% drag reduction.
The visor shows `SLIPSTREAM` while active. Flying, warp, crashed/recovering and
EMP-disabled craft cannot draft or provide a wake. The same rules apply to bots,
local controllers, touch and GameNight players.

Up to four optional airborne batteries sit above and off to the side of the
racing line, giving the same **25 energy** for a risky flying detour. Easy tracks
keep them roughly 15–20 metres above the road; normal uses 22–27 metres, hard
30–35 metres and farther sideways. Technical tracks can offer a higher, off-axis
pickup over an existing jump. These batteries are slightly larger for visibility,
require actual airborne contact, and share the two-second respawn and collection
flash. Each racer can collect each battery once per lap. Blocked approach/return
paths are omitted after scenery construction; no auto-landing is added.

The shared shield/boost bar automatically refills at **1.5 energy per second**,
after two seconds without boosting or taking damage. Refill also waits during
warp, EMP shutdown and recovery. A spent boost takes about 15 seconds of refill;
batteries and repair lanes remain much faster ways to recharge.

Small amber batteries with white plus signs float above the road between weapon
stations. Drive through one to restore **25 shield/boost energy**, up to 100.
They work while carrying a weapon and do not occupy the item slot. A golden
flash and a brief +25 beside the energy bar confirm collection (less near full).
Each battery disappears for everyone for two seconds, then returns. Full-energy
racers leave it available for others; each racer can collect once per station
per lap. Battery rows are seeded and avoid jumps, gaps and tight corners.

## Pickup weapons

Fly through the cyan pickup rows and press **X** to activate the carried item.
Pickup stations are spaced at one third of their original density, with three
lanes at each station. A collected pickup vanishes for everyone for two seconds,
then fades back in. The other lanes remain available. A short mint light pulse
and expanding rings mark the pickup and collector, visible to all players; the
inventory label briefly brightens. One inventory slot, one pickup per row per lap
per player. Bots also collect and use items.
Use buttons, timers and effects pause with the race; crashes discard items.
Every held item is visibly mounted before activation: a missile on a side rail,
a rear sentry turret, a pulsing violet warp coil, a blue EMP capacitor, or a
compact jammer dish that extends when used. Separate mounting points keep an
active sentry or jammer clear of newly collected equipment.

- **Cruise missile:** a large finned rocket lifts off its mounting rail, inherits
  the craft's motion, then ignites with a growing exhaust plume and warm light.
  It accelerates into track-following cruise over roughly one second at **1,500 km/h**,
  including banks, loops and jump routes. It locks onto the leader at launch,
  marking the plane with four blinking red corners. The targeting laser appears
  only in the estimated final two seconds and grows brighter toward impact.
  The airborne beam is thin and translucent; a bright white contact spot lights
  the targeted hull, visible from every player's camera.
  A hit deals 38 shield damage and a speed hit. A fresh
  high-G turn in the last 230 ms breaks the lock. Brake hard and steer sharply on
  the road, or make a sharp flying manoeuvre. Early held turns do not automatically
  evade. A successful dodge sends the missile past; consecutive heavy hits get a
  brief protection window. A leader cannot fire a missile at themselves. The final
  approach retains the same speed; there is no hidden catch-up acceleration.
  An exhaust trail leads into a bright impact flash and expanding smoke. A cached
  procedural bang/rumble is ready when sound is enabled; playtests remain muted.
- **Warp drive:** phases through traffic and follows the course for about 2.8
  seconds, with refracted/rainbow screen distortion and soft cyan-white filaments
  streaming off the hull. The mounted coil brightens; the craft stays exposed
  instead of being covered by a shield bubble. A transparent refraction field bends
  nearby scenery around the car in every player's view, with foreground depth
  protection and distance scaling. The wake and refraction fade out on release. It follows
  loops and split lanes and extends through a gap until it can release over deck.
  Speed tapers before handing back control, accounting for the next corner. It
  preserves lap/finish accounting and does not spend ordinary boost energy. It
  activates only on the track, so it cannot teleport a failed flight to safety.
- **Sentry gun:** a hull-mounted turret operates for eight seconds and fires at
  the nearest valid rival ahead, within 190 metres in space / 220 along the course.
  Its head aims independently, with barrel recoil and muzzle flashes. Bursts deal
  4 shield damage every 0.4 seconds. Buildings/terrain block its shots.
- **EMP:** an expanding blue-violet electrical sphere reaches 220 metres in
  0.65 seconds, cutting every rival's engines inside it for 2.2 seconds. Your own
  engines are unaffected. Rivals coast and can steer/brake, but lose throttle,
  boost and ground strafe. Warp is interrupted too, including a smooth
  transition into flight above gaps. Engines restart automatically; brief reboot
  and respawn protection prevent repeated shutdowns. No direct shield damage.
  The affected helmet HUD goes dark too, then fades back in as systems recover.
  Cruise missiles caught in the expanding pulse lose guidance and propulsion,
  coast harmlessly, and disappear. Missile launches are blocked during shutdown.
- **Jammer:** deploys an exterior satellite dish for six seconds. A 56-degree
  forward cone reaches 260 metres; rivals inside get signal tearing, static and
  bounded random steering/strafe/pitch input. Interference is strongest nearby
  and on-axis, fading with distance and at the cone edge. Escaping the cone clears
  it. Buttons, throttle and brake remain under player control. EMP silences the
  transmitter; warp and fresh respawn protection resist it. Subtle broken copper
  and cyan traces show transmission, fading with travel and at the end of use.

Touchdowns mildly damage shields according to descent speed, attitude
against the deck and sideways slip. Small imperfections are free; a typical rough
landing costs about 4 shield points, and landing damage is capped at 18. Speed loss
is reduced, and more steep/tilted approaches can recover. Extreme impacts still
wreck the craft. Banked tracks use their own
surface orientation. A depleted hull rebuilds with 25 shield points after automatic
recovery to prevent an unavoidable repeat crash at the next jump.

Catch-up bias affects only random item odds. First place never receives warp.
Warp odds increase with position and actual distance behind the leader: last
place has a 14% chance nearby, rising smoothly to 42% at 1,500 metres behind.
The distance bonus starts at 150 metres and also works in two-player races.
EMP stays at 16% and Jammer at 14%; other rolls use the missile/warp/sentry pool.
A leader's missile roll becomes a sentry. There is no hidden handling or
engine-speed penalty for leading. Items earned before taking the lead stay usable.
Damage uses the existing shield/boost-energy bar; depletion produces the normal
wreck and automatic recovery after two seconds. Respawning grants two seconds of weapon protection.

## Android tablet

`build/android/IonRush.apk` is a debug-signed APK for direct installation. Copy it
to the tablet, open it in Files and allow that app to install it when Android asks.
This is an offline standalone build; GameNight's desktop host remains on Windows.
The APK includes ARM64 (Galaxy Tab S9+) and x86-64. It locks to landscape.

Pair a controller through Android Bluetooth or connect it by USB. The same sticks,
triggers and Start menu work; late pairing is supported. Touch controls are also
available: left pad steers/yaws, right pad strafes/rolls and controls grip/pitch.
Tap **Throttle** to keep power on, leaving both thumbs free for the sticks; tap
again to cut power. Hold **Brake** or **Boost**. **Use** appears when carrying an item;
**Reset** appears off track.
The top pause button opens the shared menu. Controller use hides touch pads;
touching the screen brings them back. Pausing or backgrounding clears touch input.
Touch drives player one; extra local players need controllers.

Android uses the Mobile Vulkan renderer, a 60 FPS cap and Performance by default.
Performance/Balanced/High cap 3D width at 1280/1600/1920 pixels respectively;
UI stays at display resolution. Mobile keeps emissive lighting, glow and local
lights but omits desktop SSR, SSAO and volumetric fog. Real Tab S9+ performance
still needs device testing; desktop previews are not tablet benchmarks.

To reproduce the APK, install Godot 4.5.2 Android export templates, Android SDK
Platform/Build-Tools 35, and configure Java SDK/Android SDK in Godot Editor Settings.
Then run (Python uses only its standard library):

```powershell
python tools/package_android.py --godot C:/dev/tools/godot/Godot_v4.5.2-stable_win64_console.exe
```

The builder uses your local Android debug keystore (or the `GODOT_ANDROID_KEYSTORE_DEBUG_*`
environment overrides), verifies the APK signature/content and writes a SHA-256 file.
No signing key is stored in this repository. For a desktop touch preview, append
`-- --touch` to the Godot command; `--rendering-method mobile` previews mobile shading.

## Driving

Simulation runs at 120 Hz. LT is an analog brake: squeezing it slows the craft,
reduces magnetic grip and increases yaw authority. The hull turns ahead of its
momentum, so the craft slides outward. Brake before a sharp corner, turn into it,
then release LT and countersteer to catch the slide. A short brake tap breaks
adhesion quickly and leaves a slide after release; the nose responds faster than
the lateral momentum. Grip returns slowly, with forward trim and countersteering
helping catch the slide. Dorsal airbrakes open and orange forward-facing reverse
jets fire with brake pressure; a brief visual decay keeps short taps readable.
The right stick's horizontal axis strafes without steering the nose. LB/RB trigger a short left/right side bump: 14 shield damage on side contact, once per rival per attack, with a shared 0.9-second cooldown. Release and press again to attack; bumps require being on the track and engines enabled.
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
yaw through the rudders, and right stick left/right rolls via the wing
ailerons. The same fin mapping is visible while driving. These are
independent body-axis controls: roll sets bank, with no forced levelling or hidden
yaw. Bank and pull back to turn like a fighter. LT acts as an air brake. Angular
rates build and stop quickly with stick input; wing lift, bank, angle of attack,
side-slip and gravity still affect flight. At flying speed, pitch and yaw also
bend velocity with the nose, so hard turns redirect travel immediately instead
of letting the hull spin away from its momentum. This assistance fades below
180 m/s and disappears at stall speeds; roll alone continues to bank the wings.
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
hills, traffic and track fixtures can also be hit while flying. A crash produces
an explosion that breaks the craft into 16 hull, wing, engine and tail pieces.
Crashes and missile impacts use the Growing Guns explosion logic: lumpy 3D fire
and smoke, delayed flame tongues, embers, a refractive heat shell and a warm fading
light. Crash smoke completes its fade at the impact after the craft respawns.
The source and port details are recorded in `third_party/growing-guns`.
They carry impact momentum, tumble under gravity, bounce off scenery and the road,
then settle. Steering, throttle, braking and movable fins are disabled until
recovery. After two seconds the craft respawns automatically; pause remains available. The camera coasts briefly,
eases its aim toward the debris and keeps some distance from rebounding parts.
Y also initiates recovery while airborne: two seconds of downtime, loss of
momentum and up to 25 energy (leaving at least one). A crash already charges the
energy cost; automatic recovery does not charge it twice. Recovery
returns to the last safe track position, before a mandatory jump when applicable,
without awarding progress. Holding Y cannot trigger repeated resets. Recovery preserves remaining energy; a depleted hull is rebuilt with a 25-point reserve.
Flight has no hidden time or distance limit. Impacts with scenery, road undersides,
city ground or water still cause crashes; Y remains available when lost off course.
Ordinary flight progress is credited on landing. Flying forward through the lap
line over the road also counts immediately, up to 120 m above the deck.
Each course has a few ordered checkpoint gates, including halfway through every
loop. Pass through them on the road or in the air; shortcuts between gates are
allowed. Skipping a gate prevents lap credit and displays
`CHECKPOINT MISSED · Y TO RETURN`. Y returns to the missing gate's approach
(before the entrance for loops), using the usual recovery delay and energy cost.

Hinged wing elevons and twin tail rudders respond directly to pitch, steering,
strafing and braking, including during the starting countdown. Input deflection
is immediate; the hull and momentum retain their physical response time.
AI cornering uses coordinated steering and strafe. Fixed wings stop at the hinge
instead of overlapping the moving elevons; contrasting edges make small control
movements readable. Victory-lap controls show turns, lane corrections and braking.
During the countdown, craft rest level near the deck until RT / A (or keyboard
throttle) starts their engines. One side rises first, then the other, settling into
hover. Engine sockets brighten and develop soft blue-white halos with throttle,
even while the starting grid remains locked. This startup is cosmetic: pressing
throttle exactly at GO has the same acceleration as warming up beforehand.
Sound is temporarily disabled for playtesting, including managed pause/resume.

Cruising speed is roughly 950 km/h; boost reaches roughly 1,400 km/h. Boost
unlocks on lap two, costs 22 energy, and lasts 1.25 seconds. Release and press
again to retrigger. Wall impacts also consume energy. Green lanes repair;
amber chevrons give a free boost. Empty energy crashes the craft and starts its automatic
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

Building-mounted neon emblems, interrupted facade ribs, illuminated crowns and
colored billboard frames now give the skyline more visible light sources.
Their palette varies between city blocks while office windows retain natural
warm/cool colors. Neon signs share the road's four nearby sign reflections with
the artwork billboards; up to 16 additional distance-faded local lights provide
colored spill. Facade strips and frames use spatial instance batches and do not
add shadow passes. These accents work in Direct lighting as well as SDFGI.

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
jets, bright engine cores, and soft exhaust wisps. The engine socket glow
responds to throttle; plume length grows with actual acceleration and boost.
Exhaust sparks move backward relative to the craft at vehicle speed plus
220–380 m/s (another 220 m/s during boost), with feathered ribbons concentrated near the jets. Their
distance is integrated from the effects clock, so throttle changes cannot jump
the trail and pausing freezes it. The particle count remains fixed at 20 per craft.
Each craft has two short-range dynamic exhaust lights, one per nozzle. Throttle and boost
illuminate its hull, the road and nearby racers, including during countdown; the
lights follow free flight, track live player colors and turn off during recovery. They are shared across
views and use no shadow maps.
Boost triples nozzle light energy and increases its reach, with thin optical
flares and stronger core bloom. A small heat-shimmer shader refracts the road
behind each jet; it intensifies during boost and freezes with pause. Flares
are hidden when their source is occluded. See [boost effects](docs/boost-effects.md)
for render checks and measured split-screen performance.
During boost, uneven plasma tongues and short, forked electrical spikes erupt
from each nozzle. Each bolt lasts one rendered frame, with fresh shapes and gaps
on the next frame instead of a lingering fade. The two engines surge independently, pulsing their cores,
flares and nearby lighting; normal throttle retains a steadier exhaust.
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

Streetlights aim at the road from visible fixtures. Two nearby fixture or
billboard lights per player hold full shadows; outgoing shadows fade over half a
second, with at most four transition slots per view (16 total for four players).
Selection uses hysteresis and updates at most every 0.15 seconds. Longer distance
fades and 1024/2048 shadow atlases bound the cost. Forest and Cell sun shadows use
blended cascades reaching 1,400 m solo / 1,100 m split-screen at Balanced/High,
with a broad fade across the outer 45%. Solo uses four cascades; multiplayer,
Performance and Mobile use two to reduce CPU draw overhead.
See `docs/shadows.md` for ranges and measured costs. Exhaust and tunnel
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
fullscreen. On Forward+, Balanced and High use 2x MSAA, bloom and screen-space reflections; High also uses
ambient occlusion and volumetric haze. Reflection ray steps drop from 48 to 32 in split-screen.
Performance disables these screen-space effects and local shadows. HUD stays at window resolution.
Mobile uses FXAA on Balanced/High to preserve readable depth for exhaust optics.
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
[MIT license](LICENSE). Authored forest models use CC BY 4.0 (see credits above). Godot's license and bundled dependency notices are in `third_party`.

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
