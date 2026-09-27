# Growing Guns effects adaptations

Source: https://github.com/ontola/growing-guns
Pinned revision: `68cd40fc080acf6b5016fa8fd49b909816bc3099` (verified against HEAD).
Upstream file: `scripts/violence.gd`.
Laser source: `shaders/laser_tracer.gdshader` at the same pinned revision.

Ported at the repository owner's request for reuse of their Growing Guns effects.
The upstream checkout has no standalone license file; this notice records the
source and authorization rather than assigning a new upstream license.

`src/blast_billow.gdshader` and `src/blast_embers.gdshader` adapt the upstream
`_BILLOW_MM_CODE` and `_BLAST_PROJECTILE_CODE` shader constants. The billow shader
uses a local environment brightness uniform and handles OpenGL depth coordinates.
Smoke gradients are continuous, and billow meshes use more subdivisions for the
close racing cameras (32x18 desktop, 24x13 Mobile).
`src/blast_vfx.gd` ports `_spawn_blast_billow`, the fire/smoke/tongue/ember layer
construction, their size-dependent timing, and the flash-to-warm-light sequence.
The heat shell adapts the upstream growing refractive shell with bounded screen
displacement and depth rejection for this game's cameras.

Ion Rush uses reusable bounded layers, deterministic cosmetic seeds, and explicit
race-clock animation in place of upstream tweens, autoloads and spawn queues.
Existing ship wreck physics, combat damage, missile trails and sound settings are
preserved. No Growing Guns game content or audio samples are included.

`src/missile_laser.gdshader` adapts the laser's exponential radial falloff and
longitudinal taper. Ion Rush uses a camera-facing ribbon per view, UV-space
cross-section and faint red scattering. A separate white contact glow and local
light concentrate brightness on the target hull. Brightness follows the existing
two-second warning timer. HDR radiance is supplied through ALBEDO for Godot's
unshaded pass; the original solid cylinder has been removed.
