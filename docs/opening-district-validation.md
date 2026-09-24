# Opening district visual pass — 2026-09-24

Forward+ is now the default. The curated opening adds four safely placed landmark
advertising towers, up to 24 visible streetlights (15 on seed 31), static reflection
captures, geometric billboard reflections on wet asphalt, finer ship bevels,
clearcoat and nozzle rims. Distance fog separates foreground from the skyline.
Driving, race rules and controller mappings are unchanged.

## Validation

- Godot 4.5.2, Vulkan Forward+, RTX 5070 Ti, native 1920×1080, High.
- Four-player moving race, seed 31, 1,000 measured frames: mean 11.03 ms
  (about 91 fps), p95 13.67 ms. Existing playtest process was still open.
  This is a short local measurement, not a guarantee for other machines or 4K.
- City audit: 17,790 checks, eight layout seeds and additional dense road-surface
  sampling against streetlight envelopes on three seeds; no failures.
- Startup, throttle, braking and dynamic engine illumination: 18 checks passed.
- Source headless GameNight protocol integration passed, including hidden prepare,
  sparse controller ownership, pause/resume, stale input and dispose/reprepare.
- Packaged native Forward+ GameNight integration passed, including the new
  reflection warmup before Ready, hidden preparation and dispose/reprepare.
- Controller menu regression passed.
- Solo review captures inspected at four positions in the opening district.
- OpenGL fallback rendered all four review views; its existing sky-texture
  cleanup warning still appears at process exit (two 349,524-byte textures).
  No such warning appeared in the Forward+ runs.

## Reproduce the visual review

```sh
godot --path . --resolution 1920x1080 --script res://tests/district_render.gd -- --capture-dir=/absolute/output/district
```

The harness freezes seed 31, settles captures, and saves entry, straight, avenue
and city views. For the fallback add `--rendering-method gl_compatibility` before
`--`. Use the README demo command for moving performance measurements.

## Rendering limits

The district is a polished prototype section, not a match for the reference's
asset detail or cinematic density. Geometric sign reflections use each real
screen's position, orientation, size and artwork. They do not trace occluding
buildings or reflect the overlaid Label3D copy. Cubemap reflections approximate
nearby geometry; SSR loses off-screen information. No ray tracing is used.

Static probes need multiple render frames to populate; the managed preparation
path now warms 60 frames before Ready. High uses bloom, SSAO and SSR; Balanced
omits SSAO and reduces resolution; Performance omits all three. Four views use
32 SSR steps instead of solo High's 48 and share the static world/captures.
The OpenGL fallback omits those screen-space effects but retains geometric
billboard reflections, dynamic point lights, fixture geometry and local halos.

Godot references: [reflection probes](https://docs.godotengine.org/en/4.5/classes/class_reflectionprobe.html)
and [renderers](https://docs.godotengine.org/en/4.5/tutorials/rendering/renderers.html).
