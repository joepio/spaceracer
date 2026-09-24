# City visual pass — 2026-09-24

Native Windows, Godot 4.5.2 OpenGL Compatibility, RTX 5070 Ti.

- Imported mipmapped, VRAM-compressed facade and billboard PNG assets.
- Reviewed native 1920x1080 captures of the start, avenue, city descent, loop, tunnel, billboard close-up and four-player racing.
- City safety: 17,651 checks, zero failures across eight seeds, auditing building envelopes, actual instance bounds, signage and traffic against the swept road.
- Controller menu checks passed; muted solo starts from Start.
- Packaged Gamenight synthetic host passed authentication, prepare/start, sparse controller ownership, pause/resume, stale input, live profiles, Back, disposal/reprepare and disconnect.
- Four-player High at 1920x1080: 1,000 measured frames, mean 18.05 ms (~55 fps), p95 23.44 ms, final frame 1,030 draw calls. This is a short desktop-workload sample, not a sustained hardware benchmark.
- Native review harness reports two existing OpenGL sky texture cleanup leaks on exit after replacing its initial world. No script or shader errors were logged. The menu harness also reported an ObjectDB cleanup warning; lifecycle integration passed.

Reflection streaks approximate rail lighting; they do not mirror scene geometry. Speed blur is a five-tap peripheral radial filter with a protected craft area and separately drawn HUD, enabled at speed on Balanced/High only.


## Night lighting correction

Removed billboard hue interpolation and bright full-width color pools from the
road. Replaced broad repair/boost color fills with inset markings. Reduced the
directional fill to 0.18 with zero specular, softened the asphalt response and
balanced ambient light to preserve road readability. The sky now has a continuous
dark gradient without sinusoidal cloud bands; distance fog uses the horizon hue.
Street-grid emission is reduced and distance-faded.

Reviewed native 1080p start, city, avenue, loop and tunnel captures after two
iterations (the initial ambient pass was too dark). No script/shader errors;
the review harness still logs its previously recorded sky cleanup warnings.


## Dynamic exhaust lighting

One 19 m shadow-free OmniLight per craft, 22 m on boost. Brightness follows engine
power during countdown and the race; boost brightens it, recovery/finish disables
it. Native fixed-camera comparisons with only one craft powered demonstrate light
on its rear hull, the asphalt and a neighboring unpowered craft. The shared world
provides the same light to every split-screen camera. Effects tests: 18 checks,
zero failures (cold engine, countdown, boost and recovery included).

Four-player High follow-up (1080p, six racers, 1,000 frames): mean 9.23 ms
(~108 fps), p95 12.66 ms. Short desktop sample, not a guaranteed frame rate.
The simplified road shader removes the expensive multi-layer reflection noise.
Fixed-camera light-on/off measurements increased mean blue intensity on the own
hull by 13.49/255, road by 15.35/255 and neighboring unpowered hull by 2.18/255.
