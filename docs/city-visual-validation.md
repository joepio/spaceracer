# City visual pass — 2026-09-24

Native Windows, Godot 4.5.2 OpenGL Compatibility, RTX 5070 Ti.

- Imported mipmapped, VRAM-compressed facade and billboard PNG assets.
- Reviewed native 1920x1080 captures of the start, avenue, city descent, loop, tunnel, billboard close-up and four-player racing.
- City safety: 17,651 checks, zero failures across eight seeds, auditing building envelopes, actual instance bounds, signage and traffic against the swept road.
- Controller menu checks passed; muted solo starts from Start.
- Packaged Gamenight synthetic host passed authentication, prepare/start, sparse controller ownership, pause/resume, stale input, live profiles, Back, disposal/reprepare and disconnect.
- Four-player High at 1920x1080: 1,000 measured frames, mean 18.05 ms (~55 fps), p95 23.44 ms, final frame 1,030 draw calls. This is a short desktop-workload sample, not a sustained hardware benchmark.
- Native review harness reports two existing OpenGL sky texture cleanup leaks on exit after replacing its initial world. No script or shader errors were logged. The menu harness also reported an ObjectDB cleanup warning; lifecycle integration passed.

Reflection streaks approximate rail lighting and nearby billboard colors; they do not mirror scene geometry. Speed blur is a five-tap peripheral radial filter with a protected craft area and separately drawn HUD, enabled at speed on Balanced/High only.
