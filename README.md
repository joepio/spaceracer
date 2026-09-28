# Ion Rush

A small, original, F-Zero GX-inspired hover racer for GameNight. Godot 4.5.2;
native 3D with 1–4 local split-screen players. Bundled AI-generated city textures; no online services required.
This is a playable prototype, not an exact recreation of GX physics.

## Repository

GitHub: [joepio/spaceracer](https://github.com/joepio/spaceracer).
The game and its local launchers currently use the name **Ion Rush**.

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
It opens fullscreen from `build/warp-balance/IonRush.exe` with an immutable copy
of its current PCK in `build/debug-sessions`. New builds cannot corrupt assets
being read by an ongoing playtest. Keep updating the staged executable/PCK so
the next launch uses the latest build. The installer accepts `-BuildDirectory`.

The title and pause screens share the same menu: up/down selects a row; left/right
immediately adjusts players, world, level, seed or graphics. Use the analog stick,
keyboard arrows or on-screen arrows. A/click activates actions.
**New random race**, directly below Play/Resume, launches a different seed and
randomly chooses City, Forest or The Cell, preserving players, difficulty and lap count. In either menu, **hold X
for one second** to do this immediately. **Hold D-pad left/right** for the
previous/next seed with random scenery, or **up/down** for harder/easier; Start applies those choices.
A small progress bar shows the hold. Short taps do nothing, and a continuous
hold acts only once. These shortcuts are menu-only; racing D-pad steering stays
available.
Standalone races have six machines, filling spare positions with AI.
The camera keeps the same horizontal lens in wide two-player viewports, with a
stronger, smooth acceleration/boost FOV increase. HUD instruments sit near the corners,
with very light curvature in split-screen and no decorative cockpit brackets.
Weapon prompts sit at the lower center, with a circular X button.
Start/Escape pauses. Unchanged settings resume the current race; changing a race
setting changes the primary action to **Restart**. Graphics never resets progress.
The paused track keeps its last rendered frame behind a dark menu gradient until
resuming or restarting. Back no longer pauses.

Desktop Forward+ also has a **Lighting** row: **Direct** or experimental **SDFGI**.
Switch it in the pause menu to compare the same view without restarting the race.
SDFGI adds environmental bounce light and is opt-in; selecting it raises Performance
graphics to Balanced. Selecting Performance disables it again. Mobile keeps direct
lighting and does not show the unsupported option. `--sdfgi` enables the trial at
launch; `--direct-lighting` selects the fallback. See [the lighting experiment](docs/gi-experiment.md)
for measurements and limitations.
F5 starts the next track with random scenery. Automatic advancement after the
eight-second results screen also rolls the scenery; repeats are possible.
Direct World/seed selection and Restart race keep the displayed choices.
Three laps by default.
After finishing, an autonomous victory lap keeps your ship moving while a replay
camera cycles through rear-quarter, front, side and overhead shots. Equipped hardware
stays on the single mount; active sentries settle to idle, with queued inventory
retained in the HUD. Finishers cannot fire or interfere with the remaining racers. Other players
keep racing with their own chase cameras. Finish times and places stay locked;
the camera and victory lap pause with the game and continue behind the results.

The start menu has a five-digit **Track seed** (00001–99999). Use left/right for the previous/next code or type a code. **New random race** chooses a different code and starts immediately. Race uses the displayed code;
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
| 00035 | Velocity | Nine long boost lanes, true straights, broad end turns, narrows and a split |
| 00036 | Pipeline | Repeated half-pipes and enclosed magnetic tubes |

Other seeds vary the dimensions, hills, corner shapes and component sizes within
these families. Character is independent of scenery and difficulty. This generator
revision intentionally changes older layouts outside the Grand Circuit family;
sharing a seed requires the same game version. See [track generation notes](docs/track-identities.md).

**World** switches between the neon **City**, **Forest — Verdant Reach**, and **The Cell**.
Hard mode adds distinct hazard components to the layout families:
- Grand Circuit has a rising 360-degree spiral (a wider version also appears on Normal).
- Hard Switchback has a 44-metre-wide double hairpin with 72-metre-radius turns: brake before the apex and use yaw/strafe to hold the slide. Entry and exit rails protect the transitions; the middle remains exposed.
- Grand Circuit, Sky Circus and Velocity have a turbo launch ramp and a lower, offset landing. Push the nose down after takeoff and aim for the landing lights.
- Split routes on Hard include a warning-marked dead branch. Red Xs lead to a crash barrier or an open drop; the other branch remains passable. Signs precede the fork, and the seed selects the blocked side and ending.

Try Hard seeds **00031** (spiral, turbo jump and barrier), **00033** (exposed hairpins),
or **00037** (spiral and broken branch). Components work in all three biomes.
Easy keeps its continuous guarded road. This geometry revision changes affected seeds;
sharing a seed requires the same game build. Spiral checkpoints prevent skipping the
entire coil while preserving legal flight shortcuts between gates.

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

Guarded sections have 2.5-metre sidewalls with luminous top edges. Mounted neon
chevrons appear once before demanding corners, with up to 160–280 metres of
warning. Gentle bends are unsigned; yellow marks moderate turns, orange sharp
turns, and red is reserved for the tightest hairpins. One, two or three
bars reinforce severity; the chevrons sweep progressively faster (0.65/1.35/2.4
cycles per second) without blinking off. A cool-white broken-rail/drop pictogram
means the upcoming bend has an exposed edge. Subtle road-edge bars match the
warning color. Signs use three batched meshes and no extra lights; animation
freezes with the race. Intentional open edges and flight gaps remain open.

Item prompts sit at the lower center of each player's view, with a circular X
button matching the Y reset prompt. Active equipment and a stored pickup remain
visible on separate rows; reset notices have their own space below them.

A continuous amber line spans each takeoff edge; a cyan line spans the landing
edge. Approach beacons remain beside the road, without repeated ground bars.
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
| Grip / speed trim | Either stick forward / backward | Controller only | Controller only |
| Reset while airborne | Y | 1 | 2 |
| Pause / resume | Start | Escape | Escape |

Keyboard P3: IJKL, U boost, Y/O bump. P4: TFGH, R boost, V/B bump.
Keyboard recovery uses 3 for P3 and 4 for P4. Pickup use is P for P3 and C for P4.
Standalone assigns connected controllers at race start and fills disconnected seats when a controller is paired later. Other connected players keep their seats. Keyboard controls also work.

## Energy recharge

**Slipstream:** follow a moving rival closely to reduce drag and build extra speed
without spending energy. Stay directly behind them, ideally 20–45 metres back;
the wake fades out by 145 metres and outside its narrow corridor. Full drafting
reduces aerodynamic drag by 26%, bringing level-road full-throttle cruise from
about 954 to 1,109 km/h. It builds over half a second and fades when pulling out
to pass; braking remains fully effective. Boost gains a smaller 12% drag reduction.
The visor shows `SLIPSTREAM` while active. Flying, warp, crashed/recovering and
EMP-disabled craft cannot draft or provide a wake. The same rules apply to bots,
local controllers, touch and GameNight players.

Shared mint-green recharge strips replace floating batteries, including airborne ones.
Two or three strips per lap are chosen on broad, gentle stretches, with guardrails
through the charging area. Drive over the textured strip to gain **34 energy per
second**, up to the normal 100-energy bar. Every player can charge simultaneously:
no shared cooldown, disappearing supply, rank requirement or per-pass limit. Staying
longer restores more energy. The visor's energy gauge glows mint and shows `CHARGING`.
Weapon inventory is unaffected, and AI racers can use the same strips.

The shared shield/boost bar also keeps its slow **1.5 energy per second** refill
after two seconds without boosting or taking damage. Passive refill waits during
warp, EMP shutdown and recovery. Recharge strips provide the faster alternative.

## Pickup weapons

**Railgun:** its aiming circle is always visible while ready. A green bracket
marks the current hittable rival; press **X** to fire immediately. Rivals inside the
circle are eligible for a straight shot up to 650 m. The first vehicle hit loses
50 energy (half a full bar); road and scenery still block the shot. The circle
matches the player's camera, including split screen. Twin glowing rails mount
on the hull while carried. Firing produces a
short white-hot core, cyan afterglow, expanding ion rings and local muzzle/impact
lighting. AI pilots wait for a clear shot inside their forward aim cone.

The HUD shows active equipment and the stored item separately. An unused item
fills storage; activating a sentry frees that slot for another pickup.
Stored equipment becomes usable when the current effect ends. First place gets
a large **YOU WIN** banner in their own viewport, including split screen.

Fly through the cyan pickup rows and press **X** to activate the carried item.
Pickup stations are spaced at one sixth of their original density, with three
lanes at each station. A collected pickup vanishes for everyone for two seconds,
then fades back in. The other lanes remain available. A short mint light pulse
and expanding rings mark the pickup and collector, visible to all players; the
inventory label briefly brightens. One inventory slot, one pickup per row per lap
per player. Bots also collect and use items.
Use buttons, timers and effects pause with the race; crashes discard items.
Damage produces a compact flash, sparks, a short smoke puff and a few tumbling
soft embers at the contact point. These fade within half a second; no shield
bubble covers the craft. Sentry fire, side bumps and damaging landings use this
feedback, while missile detonations and full crashes keep their larger blasts.
Equipment uses one universal dorsal mount behind the cockpit: a missile rail,
sentry turret, warp coil, EMP capacitor, glide bomb or raised railgun adapter.
Only one module is visible at a time. An active sentry or warp drive owns the
mount while the queued item remains in the HUD; it mounts when the active item ends.

- **Cruise missile:** a large finned rocket lifts off its mounting rail, inherits
  the craft's motion, then ignites with a growing exhaust plume, white-hot core,
  warm lens streak and stronger dynamic light. The flare is depth-occluded and
  faces each split-screen camera independently; EMP cuts all motor effects.
  It accelerates into track-following cruise over roughly one second at **1,500 km/h**,
  including banks, loops and jump routes. It follows the highest-ranked active opponent, updating when the lead changes,
  marking the plane with four blinking red corners. The targeting laser appears
  only in the estimated final 0.75 seconds, fading in and brightening rapidly
  toward impact. Once the
  laser is visible, the target stays locked even if another racer overtakes.
  Finished/crashed/recovering racers are skipped before lock; a carried missile
  remains usable after its owner takes the lead, targeting the next opponent.
  With no eligible opponent it still launches, climbs away without guidance,
  and self-destructs after roughly 3–4 seconds, without a target marker or laser.
  The airborne beam stays thin and translucent; a stronger white contact spot lights
  the targeted hull, visible from every player's camera.
  A direct hit deals 38 shield damage and a speed hit. Its **32-metre blast radius**
  also damages nearby opponents (up to 26, falling off with distance), throws them
  sideways and briefly breaks road grip. Nearby airborne craft get a radial
  velocity kick. The shooter is immune; warp/recovery protection also prevents
  knockback. Direct victims are not charged a second splash hit. A fresh
  high-G turn in the last 230 ms breaks the lock. Brake hard and steer sharply on
  the road, or make a sharp flying manoeuvre. Early held turns do not automatically
  evade. A successful dodge sends the missile past; consecutive heavy hits get a
  brief protection window. A leader cannot fire a missile at themselves. The final
  approach retains the same speed; there is no hidden catch-up acceleration.
  An exhaust trail leads into a bright impact flash and expanding smoke. A cached
  procedural bang/rumble is ready when sound is enabled; playtests remain muted.
  Its pale faceted fuselage, broad grey radome and swept wings take visual
  cues from the [Green Wolf reference](https://www.navalnews.com/wp-content/uploads/2025/10/L3Harris-Green-Wolf-missile.jpg).
  A continuous camera-facing smoke ribbon follows distance-spaced flight history,
  expands into turbulent wisps and fades after impact. It uses one bounded mesh
  per trail, without a chain of separate cloud sprites.
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
  Its head aims independently, with rotating barrels, recoil and muzzle flashes. Rounds deal
  0.5 shield damage every 0.05 seconds (10 DPS). Buildings/terrain block its shots.
  Before activation its barrels rest lowered and its status LED stays dark.
  Once armed, it scans the forward arc while searching, tracks any acquired
  rival, and blinks a small mint status LED throughout its active lifetime.
  Its rear silhouette includes a finned barrel-drive motor with a spinning hub
  on one side and a black ammunition cassette and ribbed feeder on the other.
- **Glide bomb:** a rare, heavy payload with wings that unfold after launch,
  carried on the dorsal weapon cradle. Its glide path appears automatically
  while flying; **press X** to launch immediately. A 55-degree forward seeker
  acquires visible rivals up to 1100 metres away, including over open air.
  Green brackets identify the target, with a live interception dot and guided
  steering guide. With no lock, an amber impact area shows the unguided drop.
  Every player's preview refreshes each physics tick (120 Hz), with no stagger
  or delayed marker smoothing. Aim, speed
  and release timing matter: a short 1.25-second rocket burn pulls the payload
  ahead at up to 1296 km/h, then it glides. The guide includes this acceleration;
  locked indicators use a lightweight live intercept instead of simulating a
  full future collision path. AI racers do not compute hidden HUD trajectories.
  Contact with the launching hull only arms after physical separation; launch
  self-blast protection ends once it first clears the pilot's blast radius. It steers at
  about 66 degrees per second, cannot switch targets, and loses lock if a rival
  escapes its forward seeker. Landing or EMP cancels aiming without spending
  the item. An 18-metre proximity fuse catches close passes of its locked rival;
  roads, scenery and aircraft can also trigger its
  **120-metre blast**; a full-energy craft within roughly 52 metres is destroyed,
  and a rival 60 metres away takes about 92 damage, with damage
  and a strong sideways/airborne shove fading toward the edge. The launching
  pilot can be caught too. Missed bombs fall through track gaps and expire
  harmlessly. A large fireball, billowing smoke, heat distortion and dynamic
  flash mark impact. AI pilots use the same target acquisition when airborne.
- **EMP:** an instantaneous map-wide shutdown cuts every rival's engines for
  2.2 seconds, regardless of distance or altitude. A blue-violet shell expands
  around the firing vehicle as a visual effect. Your own
  engines are unaffected. Rivals coast and can steer/brake, but lose throttle,
  boost and ground strafe. Warp is interrupted too, including a smooth
  transition into flight above gaps. Engines restart automatically; brief reboot
  and respawn protection prevent repeated shutdowns. No direct shield damage.
  A 500 ms burst of signal tearing and chromatic glitches fades into helmet HUD
  blackout; instruments return as systems recover. Controls are never randomized.
  Affected hulls spit a few short, blue-white electrical arcs along their engine
  housings and wing roots throughout shutdown, fading before reboot. These are
  sparse surface sparks, not a shield bubble; one shared ribbon mesh per car
  animates in the shader and freezes with pause, without extra light passes.
  Cruise missiles anywhere on the map lose guidance and propulsion,
  coast harmlessly, and disappear. Missile launches are blocked during shutdown.


Weapon and side-bump kills show `DESTROYED {pilot}` on the attacker's visor for
500 ms, fading out briefly. Multiple simultaneous victims get separate lines;
ordinary hits and self-destruction do not produce a confirmation.

Vehicle condition follows the energy meter: light permanent scuffs at full
energy, then longer scratches, paint chips, exposed metal and scorched engine
panels as energy falls. Recharging restores the finish toward its lightly worn
baseline. Below 22 energy, the engine panels emit soft dark smoke; it stops on
repair, crash or recovery and freezes during pause. Hull and white trim use the
same shared 512px packed mask in their existing opaque material pass. Smoke is
one draw with at most twelve quads per critical craft. Geometry and collisions
are unchanged. The generator is `tools/generate_paint_wear.py`; visual QA and
effect-on/off split-screen measurements are in `tests/vehicle_wear_render.gd`
and `tests/vehicle_wear_performance.gd`.

The white nose, engine, wing and rudder markings are painted inside the hull
shader, not separate raised meshes. Engine stripes follow the loft UVs through
the taper; other markings follow each component's local surface, including
moving rudders. They share the underlying paint's lighting, wear and rebuild
scan, with anti-aliased edges and no extra material pass.

After a crash, the camera carries a little momentum into a smooth trip toward
the exact safe respawn point during the existing two-second recovery delay.
It arrives before the craft and hands back to the normal chase camera without
a cut. Checkpoint returns and jump-safe recovery share that same destination.
Respawning uses a 0.7-second cyan construction scan: the painted panels fill
from bottom to top, a holographic grid fades away, and a short local light
illuminates the road. It adds no gameplay delay; steering resumes immediately.
The camera and scan both freeze on pause. Extra material passes and the light
are disabled completely when reconstruction ends.

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
EMP stays at 16% and Jammer at 14%; a rare dive-bomb roll replaces part of the sentry pool (about 4–7% overall).
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

Either stick forward lowers the nose and adds grip/downforce at the expense of
speed. Pulling back raises the nose; a partial pull trades grip for speed. Holding
full back at racing speed progressively unloads the magnetic suspension. The
craft rises, its wings buffet gently, and a “Lifting” cue appears before release.
Ease the stick forward during this warning to settle back down. Sustained back
input releases into independent flight, carrying the actual track velocity and
attitude through takeoff with no added kick. Crests can also unload adhesion.
At cruise speed, a full pull releases in about half a second. The first 0.3 s
of this deliberate lift-off blends measured road acceleration and angular rate into aerodynamic
forces and fighter controls, avoiding an abrupt pitch/lift surge at release.

In flight, either stick forward/back pitches down/up, left stick left/right controls
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
Hard difficulty also makes opponents race more aggressively: they carry speed
through sweepers, brake for the apex, and spend boost on more corner exits while
keeping a small damage reserve. They use the same acceleration, grip, boost cost
and lap-two unlock as players. Easy and normal retain their gentler corner pace.
All difficulties allow full boost speed on clear straights. Pilot-specific seeded
reaction times and pauses between bursts stagger boost use rather than triggering
the whole pack at the lap line. Exhaust boost effects stop when braking cancels
boost thrust.
`tests/ai_pace.gd` compares three-lap runs across all six track families against
the same steering/flight controller with ground braking and boost disabled;
add `-- --race` to test that driver against five armed opponents.
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

The racer now follows the selected red twin-engine concept: a narrow chisel nose,
large painted engine housings, recessed grilled intakes, swept ivory-marked wings,
independent elevons and tail rudders, opening cooling brakes, and machined nozzle petals.
The physical model is 2,812 triangles across 41 material surfaces, retaining the
existing collision width and all player paint/face customization. The editable
[GLB and design notes](docs/vehicle-concepts/model-v1.md) include named control pivots.
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
lights remain shadow-free. City uses thin distance haze and a dim blue-grey skyglow
to separate distant blocks while keeping the nearby track clear. This reuses the
existing fog pass on every quality tier. High adds short-range, light-responsive
volumetric mist; Balanced omits it. Forest and Cell retain their own atmosphere.
`tests/city_haze_render.gd` captures a fixed before/after scene and GPU timings in
one- and two-player views. Screen-space indirect lighting was measured and disabled because its
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

Prepare builds the world and renders 60 warm frames off-screen before Ready.
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


## Developer item shortcuts

Press **F8** to toggle dev cheat mode (or launch with `-- --dev`). A small amber
legend confirms it is active. During a race, **D** gives glide bombs, **M** cruise
missiles, **W** warp drives, **S** sentry guns, **E** EMPs and **G** railguns to every
active human and AI racer. It only equips the item: players still press **X** to
use it, and glide bombs still require flight. Existing active effects keep running;
finished/crashed racers are skipped. Each press replaces the carried item only.
These letters stop controlling keyboard driving until F8 is turned off;
controllers continue normally. Cheats stay off by default, including GameNight.

## Local GameNight registration

`tools/register_gamenight.ps1` adds **Ion Rush (Local)** to
`%LOCALAPPDATA%/GameNight/local-games.json`, preserving other local entries.
The desktop launcher merges that file into its regenerated shelf on every start;
local IDs take priority over catalogue builds. The managed launch script takes
an immutable snapshot of the latest staged Windows PCK and waits for the game,
so the host owns the entire process lifetime. Rebuild the staged PCK and the next
GameNight launch uses it automatically.

Player artwork is composited with their skin/accent colours and painted on both
outer engine housings. It uses the hull lighting, preserves transparent artwork
and hats, and updates by player identity. Cached textures rebuild only when the
profile changes, with no separate decal draw calls. Hidden ready/paused sessions
suspend their 3D and visor viewports; warm-up completes before Ready. The host
also exposes a five-digit seed setting (zero selects a random seed).

The local Windows launcher, daemon and lobby must use the current host-controller
protocol. The installed preview was updated locally for this integration; backups
sit alongside its binaries. A future upstream app update can replace those local
binaries; the registration file remains in user data. The GameNight checkout
contains the persistent local-shelf support for future builds.

`tests/local_gamenight.py` checks the installed host, local registration, managed
launcher and native hidden preparation with isolated party/profile state. The
synthetic suite additionally covers controller routing and session transitions.
Physical multi-controller couch testing remains a hardware check.

Paid boost stacks with turbo strips: the combined target is 475 m/s versus 390 m/s
for either alone. Acceleration opens the lens more strongly, capped at a 100-degree
reference FOV with split-screen correction. Above 365 m/s, adhesion progressively
weakens and steering becomes more sensitive; nose-down trim restores stability.
Weapon pickup rows are halved again; energy battery placement is unchanged.

The mounted sentry uses six rotating barrels at 20 rounds per second (0.5 shield damage each, still 10 DPS). Tracers and the compact muzzle light are presented for one render frame per shot. Boosting leaves two short world-space light trails that bend with the driven path, with a soft colored halo and subtle analog red/cyan bleed. They fade within 0.38 seconds and clear on crashes or respawns.

City air traffic runs in opposing streams at three heights. Four shared compact,
sedan, coupe and cargo meshes have white front lamps and red rear lamps, with
varied paint. Opaque emissive lenses use scene bloom without adding individual
lights or shadows. Corridor MultiMeshes move in the shader using the race clock,
so pause freezes them; nearby collision queries use the same analytical poses.
Air lanes keep safe headways and full road/building exclusion. The sentry mesh is reduced to 1,782
triangles and 14 surfaces, retaining its animated rotor, barrels and status LED.

The city also carries up to 640 large building-mounted corporate posters:
SABLE cybernetics, SOMA designer neurochemistry, TALLY credit, VEIL privacy,
MONOLITH megacorp propaganda and APERTURE optical implants. Full-color portrait
advertisements replace the earlier retro neon storefronts. Panels and backings
are instanced by district; all six campaigns share one mipmapped color atlas.
The existing 64-light city budget and four-nearby-sign road reflection budget
stay fixed. Sign placement preserves the existing artwork billboards and road
clearance. Poster sources and generation prompts are in `docs/city-advertising`.

The city follows a strict 120-metre Manhattan street grid. Whole-block towers,
paired buildings and four-building blocks share aligned frontages and low
podiums; seed 31 has about 3,500 buildings, compared with roughly 1,050 before.
Ground streets have dashed lane markings, crossings and about 17,000 background
cars across the entire city. Cars circulate around blocks with rounded turns;
neighbouring blocks form opposing lanes, while congested blocks creep slowly.
Four low-poly meshes are shared in spatial batches. Movement and heading run in
one shader, with no individual vehicle nodes, lights or shadows. Ground collision
queries return immediately above street level and inspect nearby blocks below it.

The glide bomb shows its acquired rival automatically while airborne, even if the predicted landing point is off-screen. Its longer 1.25-second launch motor, stronger limited steering, curved-road lead prediction and 18-metre proximity fuse help well-aimed releases connect. The blast radius and damage are unchanged.

Flight engines deliver stronger thrust below normal flying speed, tapering smoothly from 140 to 44 m/s² as forward airspeed rises from 90 to 210 m/s. Full throttle can recover slow flight; a modest nose-up attitude helps arrest descent. Gravity, unpowered stalls, EMP shutdown, and the 235 m/s airspeed cap remain in effect.

Crashes shed the actual hull, wings and engine housings, with current vehicle colors under irregular black scorch patches. Small volumetric flames follow four tumbling components and fade before recovery. Generic box confetti and flat metal chips have been removed from crash and hit effects.
