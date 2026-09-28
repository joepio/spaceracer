# Growing Guns explosion port

The crash and missile explosions now use the actual billow/ember shaders and
layer placement/timing logic from the owner's Growing Guns repository, pinned at
`68cd40fc080acf6b5016fa8fd49b909816bc3099`. Provenance is recorded in
`third_party/growing-guns/README.md` and ships with the Windows package.

The four shared mesh layers provide turbulent smoke, hot core fire clouds,
staggered radially stretched flame tongues, and fast outward embers. Shader
parameters animate growth, per-puff stagger, heat and fade. A small refractive
shell and a white-to-orange light supply the initial impact. Soft depth
intersections avoid hard cuts through the road. Higher billow subdivisions and
continuous smoke gradients adapt the look to close racing cameras.

SpaceRacer's race clock replaces upstream tweens. Cosmetic seeds never consume
the gameplay RNG. Existing damage, ship breakup, fragment physics and sound
settings are preserved. Crash smoke lasts 2.84 s at the original impact point,
so its tail can finish after the two-second respawn. Missile smoke lasts 2.32 s.

Twenty-four missile slots and one crash slot per craft reuse their render nodes
and materials. Only instance data is regenerated for a new event. At most three
heat shells and ten blast lights are active in a rendered frame; particle layers
do not allocate per-puff nodes or per-frame tweens.

## Checks

- `tests/crashes.gd`: 44 checks, including smoke finishing after recovery.
- `tests/wrecks.gd`: 47 checks, including existing breakup and momentum.
- `tests/blast_render.gd`: native fire/smoke snapshots, rendered pause stability,
  fade-out, reuse across 70 blasts, and concurrent light/heat limits. Checked on
  Forward+, Mobile and OpenGL on the Windows PC.
- `tests/weapon_render.gd -- --missile-showcase`: three-camera missile impact,
  with the trail and pooled blast checked independently.

Native lifecycle capture:

```text
godot --path . --audio-driver Dummy --position -20000,-20000 --resolution 1280x720 --script tests/blast_render.gd -- --out=C:/dev/ion-rush-captures/explosions/forward
```

Android packaging is not part of this visual iteration.

The three-view Cell missile scene at 1920x1080 (three 960x540 views), seed 31/hard,
measured 8.39 ms median / 11.00 ms p95 wall time and 1.45 ms median GPU time on the
RTX 5070 Ti. This is a short PC measurement with background jobs left running.
