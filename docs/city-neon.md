# City neon pass

Adds physical facade ribs and crowns, framed billboard artwork, and thick mounted
neon emblem panels. All placements use existing building volumes and their road
clearance envelopes. No floating text boards or global exposure changes.

The road uses the same procedural emblem shader as the sign itself when a
reflection ray hits its plane. It still selects at most four nearby screens
per road section. Building ribs use scene reflections/GI rather than a new
analytic reflection pass. Existing reflection limitations still apply.

Up to 64 panels and 16 additional local lights are allowed; each light serves a
different stretch of track and fades by distance. The existing two selected
shadow lights per player budget remains unchanged. Small luminous facade strips
and billboard frames are spatially batched and do not cast redundant raster
shadows. The new effects are present in both Direct and SDFGI modes.

Validation: native City suite passed 24,853 checks, including rendered MultiMesh
road clearance and attached sign housing bounds. Lighting policy passed 120
checks and the GI suite passed 1,293. Native Direct and SDFGI screenshots and
the deterministic three-player moving route completed without shader errors.

Final seed 31 Hard City, High, RTX 5070 Ti, 1920x1080 output:

| Capture | GPU median | Render CPU median | Full frame p95 |
| --- | --- | --- | --- |
| Solo static, SDFGI | 1.82 ms | 1.40 ms | 4.96 ms |
| Solo static, Direct | 1.44 ms | 1.39 ms | 4.46 ms |
| Three players moving, SDFGI | 4.06 ms | 4.48 ms | 13.36 ms |

The moving run uses the same 360-frame scripted route as the GI experiment.
The existing game and background services were left running; no other test
process overlapped these final measurements. These are short desktop samples,
not guaranteed frame rates or tablet measurements. No Android rebuild.

Original and final same-camera captures:
`C:/dev/ion-rush-captures/gi/compare-city-after.png` and
`C:/dev/ion-rush-captures/gi/neon-final.png`.
