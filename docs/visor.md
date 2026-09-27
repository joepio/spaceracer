# Helmet visor HUD

Each player has a transparent, 2D-only instrument SubViewport at output resolution.
A lightweight composite curves the instruments around the screen edges and adds
their light over the world. A small optical halo and peripheral ghost accompany
the sharp core. The smoked-glass film and local contrast undercoat have a combined
alpha capped at 0.38; there are no opaque instrument panels. The scene camera and
the driving surface are not warped by this effect.

The layout uses open rim brackets, a segmented energy arc, a radar-style solo map
and a small flight roll reference. Item and warning messages retain their meaning;
missile brackets are precompensated for the lens sampling transform so they stay
on the projected ship. Results and victory captions share the projection, with
less edge shading during replay. Interactive start/pause controls retain their
normal hit targets; hiding the HUD also hides the compositor and disables its
instrument viewport until resumed.

EMP immediately blanks the affected player's instrument projection and suspends
its 2D viewport updates. The faint physical glass remains. The emitter's visor
stays powered; affected instruments fade back over 0.2 seconds after the existing
2.2-second engine shutdown. A three-view native test verifies blackout, emitter
immunity, update suspension and reboot. The instrument texture is explicitly
bound as a sampler uniform so both headless and native shader compilation work.

Native validation covered City, Forest and Cell, three-player Forest readability,
two-player missile tracking (9 checks), controller menu navigation/pause/resume
and graphics scaling (0 failures), and victory/results rendering (32 checks).
The desktop Mobile renderer also compiled and rendered the visor successfully.
This is not tablet performance validation; no Android package was rebuilt.

The benchmark now includes instrument-viewport render timestamps. On the existing
360-frame City route, High/SDFGI, RTX 5070 Ti, three 960x540 player views at 1080p:
median GPU 4.08 ms, median rendering CPU 4.69 ms, full-frame p95 16.11 ms. The
existing game and background services remained running. This short sample is
not a guaranteed frame rate or a precise isolated cost of the visor.

Captures live in `C:/dev/ion-rush-captures/gi`: `visor-city-v2.png`,
`visor-forest-v2.png`, `visor-cell-v2.png`, `visor-forest-3.png` and
`visor-mobile-final.png`. Missile and results captures are in the adjacent
`missile-warning` and `victory` directories.
