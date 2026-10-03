# Development validation — 2026-09-24

Godot 4.5.2 stable, native Windows, NVIDIA RTX 5070 Ti (driver 610.74).
These are local development checks, not GameNight release certification.

Latest free-flight / articulated wings revision:

- Full 197,009-check simulation suite, menu event checks, and packaged headless
  host lifecycle passed. The host test now retries partially-written diagnostic
  probe reads; this fixes a test-observation race, not a controller behavior change.
- 26 focused checks passed: pitch direction, flat-road takeoff, independent world
  trajectory and attitude, no airborne lap credit, banked/inverted landings,
  missed/underside/hard landings, crash respawn, lap-seam projection and wing inputs.
- Two closed-loop pilots took off and returned to actual seeded circuits using
  only ordinary bounded player inputs, demonstrating a recoverable full flight.
- Native off-screen rendering confirmed nose-up takeoff and articulated wing/tail
  meshes, with sound muted. The existing two sky-texture cleanup errors occur at
  screenshot-harness exit; no script or shader errors were reported.

Previous sliding / right-stick controls revision:

- 197,009 checks passed: 40 seeded geometry checks, brake pressure / slide / catch,
  right-stick speed-versus-grip, crest lift, controlled landing, runaway recovery,
  analog strafing and host stick-axis mapping. 48/48 bots completed twelve
  three-lap races; longest race 115.01 seconds.
- Synthetic controller menu events verified analog navigation, A selection,
  preserved focus after player/graphics changes, Start launching the selected
  player count, and muted audio. Added the menu regression to Windows CI.
- Packaged headless host checks include analog LT pressure and right-stick
  controller ownership. Native off-screen two-view pose review confirmed the
  slide / airborne HUD states, road geometry and muted output at 1920x1080.
- Sharper corners retain track clearance across all 40 tested seeds. Native
  hardware driving feel still requires the user's ongoing controller playtest.

Previous playtest fixes:

- 192,840 simulation checks passed; 48/48 AI racers finished 12 three-lap races,
  longest 102.62 s. Added grid clearance, rotated hull contact, rear impact momentum,
  lap-seam contact, rail crowding and 100 ms strafe-response regressions.
- Packaged host integration passed in headless mode after these changes.
- Visually checked normal/boost exhaust in two-player native 1920x1080 output;
  confirmed each 3D viewport is 1920x540. High now follows actual output pixels,
  so the earlier Balanced performance figures below do not predict native 4K speed.
- The temporary off-screen screenshot harness logged two renderer texture cleanup
  errors at exit after replacing its scene; no script/shader errors were reported.
  Packaged headless host integration exited cleanly.

Latest wildlife + minimal UI revision:

- Packaged native WebSocket lifecycle check passed, including frozen animal head
  animation during pause, profile changes, controller ownership and disconnect.
- Final packaged four-view render, seed 31 from progress 0.02: 1,770 measured
  frames, 8.36 ms mean (about 120 fps), 9.09 ms 95th percentile and 535 draw calls
  at capture. Same Balanced / 1280x720 settings below; a short local benchmark,
  not a lower-end hardware guarantee.
- Single-view skyline capture: 70 frames, 8.33 ms mean, 8.72 ms 95th percentile.
- Inspected the title screen, expanded controls, race results, single-player HUD,
  four-player HUD, and giraffe / elephant / flamingo silhouettes from the road.
  No script or shader errors in the final packaged runs.

Earlier track / vehicle revision checks (driving code unchanged):

- Visual revision simulation: 192,797 checks passed, including 40 seeded track geometry checks
  and 12 full three-lap, four-racer AI races. All 48 racers finished; the longest
  race lasted 102.97 simulated seconds. Checks now include inverted frames,
  correct hover height through loops, continuous camera roll, over 350 m of
  vertical relief, and clearance between non-neighboring road sections.
- Actual game process, synthetic WebSocket host: authentication, off-screen
  preparation, sparse/reversed controller tokens, explicit start/pause/resume,
  frozen simulation and animated scenery, live profile ownership, stale-input release, Back debounce,
  dispose/reprepare and clean disconnect passed on the packaged Windows PCK.
- Final packaged visual revision, four-view render (seed 31, starting near the
  first loop): 1,770 measured frames, 9.35 ms mean (about 107 fps), 12.26 ms
  95th percentile, 465 draw calls at capture. A preceding run averaged 112 fps.
- Final packaged single-view loop screenshot: 90 measured frames, 8.34 ms mean,
  8.97 ms 95th percentile, 177 draw calls. This short run is a visual check,
  not a sustained performance measurement.
  Balanced preset, 1280×720 window, 1600×900 logical canvas, 80% 3D render scale,
  2x MSAA, 120 fps cap. Frame intervals use the monotonic clock, not simulation dt.
- Loop entrance, inverted section, skyline dive and four-view screenshots were
  visually inspected. No script
  or shader errors occurred in the final packaged checks.
- `git diff --check` passed. A Windows CI workflow now runs simulation and
  headless host integration; that workflow has not been run remotely here.

Not verified: physical gamepad feel and hot-plug ownership, lower-end GPUs,
macOS/Linux native window behavior, real-daemon end-to-end launch, or long-running
thermal performance. The engine/runtime is portable, but only Windows was tested.
There is no public download entry or online multiplayer in this prototype.
