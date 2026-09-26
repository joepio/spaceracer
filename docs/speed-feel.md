# Speed presentation — September 26, 2026

The chase camera now responds to velocity, actual acceleration and boost
separately. Acceleration creates a brief lens surge that settles at cruise;
boost ramps toward a wider field of view and a small additional pull-back.
The field of view remains bounded at 76–103 degrees. Boost vibration is below
five centimetres, with approximately 0.2 degrees peak pitch, 0.12 yaw and 0.08
roll. Shake is applied after the underlying chase transform and cannot
accumulate into drift or alter vehicle physics.

An eight-tap radial blur increases toward the screen edges. The central racing
line, player craft and subsequent HUD rendering remain protected. The floating
camera motes were removed after playtesting. A faint, smooth
peripheral shade builds under boost instead, with no individual lines or dots.
Performance disables blur. There are no added world lights,
physics bodies or particle simulation. Menu, countdown, recovery and finish
states suppress these effects; managed pause freezes both animation clocks.

## Verification

- 612 targeted checks passed: acceleration response/settling, boost lens bounds,
  vibration displacement, orientation stability, pause and independent views.
- Existing 43 flight/camera checks and controller menu tests passed.
- Source and packaged native GameNight integration passed, including new particle/camera-clock
  pause assertions. Native Forward+ renders were reviewed at 1080p solo and
  four-player, including maximum boost.

## Rendering measurements

These measurements describe the original particle version; the later input and
presentation revision removes those particles. Raw captures of its airborne HUD
and local pause menu are under `C:/dev/ion-rush-captures/controls/`.

RTX 5070 Ti, Godot 4.5.2 Forward+, High at 1920×1080, four 960×540 views,
five-second warm-up and 1,200 samples per run. The old playtest was closed.

| Scenario | Mean measured GPU time | Wall frame p95 | Mean system CPU |
|---|---:|---:|---:|
| Frozen boost scene, blur/motes disabled | 1.836 ms | 6.696 ms | 34.7% |
| Same camera/scene, blur/motes enabled | 1.863 ms | 8.500 ms | 59.5% |
| Moving race through the jump | 1.522 ms | 17.095 ms | 67.9% |

The 0.027 ms GPU difference is small enough to be measurement noise; this is
one comparison, not a guaranteed overhead or frame rate. Runner-driven Chrome,
Node and npm jobs were active and were left untouched. CPU contention increased
between runs, so wall-frame differences cannot isolate the effect cost.

Raw evidence is under `C:/dev/ion-rush-captures/lighting/` with prefixes
`speed-post-off-4`, `speed-post-on-4` and `speed-feel-moving-4`. The benchmark
accepts `--speed=390 --boost` and `--ablation=no-speed-post` for the frozen
comparison. Solo preview: `C:/dev/ion-rush-captures/speed-feel/boost-preview.png`.
