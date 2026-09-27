# Split-screen lens and performance review

Measured 2026-09-27 on Ryzen 9 5900X / RTX 5070 Ti, Godot 4.5.2 Forward+.
The existing interactive game remained open. Background activity was not stopped.
One Windows process-counter sample reported WSL at 1547% process CPU (about
15.5 logical cores of 24); Linux had active headless Chromium and Node processes.
These are contended-session observations, not isolated hardware benchmarks.

## Changes

- Chase lens changed from 76–103 vertical degrees to 72–89 at reference 16:9.
- Wider viewports preserve the reference horizontal angle instead of expanding
  sideways. Crash and victory cameras use the same aspect correction.
- Visor curvature changed from 0.16 to 0.035 solo / 0.010 split-screen.
- Removed decorative corner brackets, shifted instruments toward screen edges,
  moved weapon readout to lower left, retained additive illumination and EMP blackout.
- Moving benchmark ignores controller input and records physics/presentation timing
  independently. An initial after-run was accidentally paused by external controller
  input and was discarded (`split-4k-after`); use `split-4k-final` instead.

## Measurements

`tests/lighting_bench.gd`, High quality, seed 31 Normal City, two views on opposite
parts of the circuit. Moving run advances exactly two 120 Hz physics ticks per
sample. Same final camera transform before/after. Near-4K output was 3840×2119
(the Windows usable-area limit), with 3840×1059 per-player render surfaces.
No resolution or lighting-quality reduction was used for the lens comparison.

| Moving, 240 samples | Before | New lens/HUD | New lens/HUD + SDFGI |
| --- | ---: | ---: | ---: |
| Frame median ms | 25.771 | 23.543 | 25.404 |
| Frame p95 ms | 29.715 | 27.728 | 29.901 |
| GPU median ms, summed viewports | 4.040 | 4.066 | 6.094 |
| Render CPU median ms | 7.400 | 6.342 | 6.975 |
| Two physics ticks median ms | 5.309 | 5.346 | 5.501 |
| Presentation update median ms | 3.857 | 3.842 | 3.864 |
| Final frame draw calls | 2000 | 1346 | 1346 |

A separate frozen 2560×1440 two-view pair had 2353 → 1677 draw calls and
9.877 → 9.338 ms median whole-frame time. The narrower frustum reduces CPU
submission, while GPU time remains similar. SDFGI adds cost but does not explain
most of the observed moving-frame time. Physics/presentation work and background
CPU contention remain material; this does not establish 60 fps under current load.
Lighting defaults to Direct; SDFGI stays optional.

Raw JSON/CSV/screenshots: `C:/dev/ion-rush-captures/gi/split-before`, `split-after`,
`split-4k-before`, `split-4k-final`, `split-4k-gi`.
Visual checks cover solo City, two-player City and four-player Forest.
