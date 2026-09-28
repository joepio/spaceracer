# Red twin-engine racer

The first red image concept is implemented in `src/racer_design.gd`, built by `Ship.build` and used for every racer. Player-specific colours and GameNight portrait decals remain dynamic. The physical hull stays inside the existing gameplay width; driving physics are unchanged.

- [Editable GLB](red-racer-v1.glb): geometry, PBR materials, named elevon/rudder/airbrake pivots and `WeaponSocket`. The game animates these pivots from existing inputs. Optical exhaust effects and gameplay shaders remain in Godot; the GLB uses portable standard materials.
- [Front view](red-racer-front-v1.png)
- [Rear view](red-racer-rear-v1.png)
- [Racing camera](red-racer-game-v1.png)

## Construction and mounting

The central hull, separate nacelles, swept wings, machined intakes, engine petals, ivory markings and cooling vents are closed or deliberately recessed 3D geometry. Repeated trim inside a component is combined to reduce draw calls. Body paint, glass, graphite structure and machined metal have separate material responses. There are 2,812 physical triangles and 41 physical material surfaces, excluding existing optical VFX and equipped weapons.

All six equipment types share the dorsal hardpoint behind the cockpit. Only the active/equipped module is displayed. Queued equipment stays in the inventory HUD while a sentry/warp effect occupies the socket. Projectile launch positions agree with the new mount; the railgun has a raised adapter to clear the canopy. Missile size remains consistent through release. Finished racers retain one visible idle module.

Crashes use the revised body sections and decorated wing/engine parts, retaining current paint under scorch shading. Control surfaces remain separate and react to pitch, roll, yaw and braking.

## Validation

Native front/rear/top/control-pose renders and all six mounted modules were inspected. GameNight faces remain visible on both outer nacelle sides. Native racing-camera views were inspected at one and two players.

On this machine's RTX 5070 Ti, the frozen city scene at 1280×720 measured median viewport GPU time of 0.831 ms (one view) and 1.114 ms (two 1280×360 views, summed). These exclude CPU simulation and final UI composition and are not Steam Deck or Android performance claims.

Geometry/winding, equipment exclusivity, flight/control animation, wrecks, railgun, glide bomb, cruise missile, mounted launch and victory tests pass. The reset-cost test isolates charging strips so it checks the reset mechanic independently of the recovery location.

Regenerate the editable GLB with Godot 4.5.2:

```text
godot --headless --path . --script tools/export_racer_model.gd
```

The exporter reads its GLB back and checks the control pivots and weapon socket.
