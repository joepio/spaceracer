# GameNight settings

These options are declared over GameNight's typed settings protocol. The phone and lobby assistant discover the same keys, labels, ranges and current values. No game-specific model prompt is required.

| Key | Control and timing | Values | Default |
| --- | --- | --- | --- |
| `laps` | Laps (next race) | 1 to 5 | `3` |
| `difficulty` | Track difficulty (next race) | easy, normal, hard | `"normal"` |
| `biome` | World (next race) | city, forest, cell | `"city"` |
| `seed` | Track seed, 0 = random (next race) | 0 to 99999 | `0` |
| `quality` | Graphics (live) | performance, balanced, high | `"high"` |
| `boost_cost` | Boost energy cost (live) | 5 to 50 | `22` |
| `boost_duration` | Boost duration % (next boost) | 50 to 200 | `100` |
| `energy_refill` | Energy regeneration % (live) | 0 to 300 | `100` |
| `respawn_seconds` | Crash recovery, s (live) | 1 to 5 | `2` |
| `weapon_pickups` | Weapon pickups (next race) | On / Off | `true` |

Boost cost uses the same 100-point reserve as shields. Regeneration pauses after damage and while boosting. Duration affects the next boost, not a boost already underway. Turning weapon pickups off removes stations on the next race; it does not erase an equipped weapon mid-race. Crash recovery changes the waiting threshold, including a crash already in progress.

All numeric inputs are integers. Invalid types, unknown keys and values outside the declared range leave the previous value intact. Live options update without restarting; structural options wait for the boundary named in the label. Party choices use GameNight's existing saved configurations and Undo/Keep flow.

The lobby owns seats and controller bindings. These options cannot add human players, remap controllers or write arbitrary engine variables. Renderer/debug internals are not exposed as gameplay controls.

## Verification

The headless settings tests exercise validation and gameplay effects. The public `scripts/test-godot-settings.py` in the GameNight repo also runs the actual game against a real daemon and checks typed updates and Undo. These source checks do not certify older downloaded binaries.

Run `godot --headless --path . --script res://tests/settings.gd`.
