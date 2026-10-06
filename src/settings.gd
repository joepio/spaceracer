extends RefCounted
## One declaration is shared by the host, assistant and gameplay validation.
const SPECS = [
  {
    "key": "laps",
    "label": "Laps (next race)",
    "kind": "number",
    "default": 3,
    "min": 1,
    "max": 5
  },
  {
    "key": "difficulty",
    "label": "Track difficulty (next race)",
    "kind": "choice",
    "default": "normal",
    "options": [
      "easy",
      "normal",
      "hard"
    ]
  },
  {
    "key": "biome",
    "label": "World (next race)",
    "kind": "choice",
    "default": "city",
    "options": [
      "city",
      "forest",
      "cell",
      "desert"
    ]
  },
  {
    "key": "seed",
    "label": "Track seed, 0 = random (next race)",
    "kind": "number",
    "default": 0,
    "min": 0,
    "max": 99999
  },
  {
    "key": "quality",
    "label": "Graphics (live)",
    "kind": "choice",
    "default": "high",
    "options": [
      "performance",
      "balanced",
      "high"
    ]
  },
  {
    "key": "boost_cost",
    "label": "Boost energy cost (live)",
    "kind": "number",
    "default": 22,
    "min": 5,
    "max": 50
  },
  {
    "key": "boost_duration",
    "label": "Boost duration % (next boost)",
    "kind": "number",
    "default": 100,
    "min": 50,
    "max": 200
  },
  {
    "key": "energy_refill",
    "label": "Energy regeneration % (live)",
    "kind": "number",
    "default": 100,
    "min": 0,
    "max": 300
  },
  {
    "key": "respawn_seconds",
    "label": "Crash recovery, s (live)",
    "kind": "number",
    "default": 2,
    "min": 1,
    "max": 5
  },
  {
    "key": "weapon_pickups",
    "label": "Weapon pickups (next race)",
    "kind": "toggle",
    "default": true
  }
]
var values: Dictionary = {}

func _init() -> void:
	for spec in SPECS: values[spec.key] = spec.default

func change(key: String, value: Variant) -> bool:
	for spec in SPECS:
		if spec.key != key: continue
		match spec.kind:
			"number":
				if typeof(value) not in [TYPE_INT, TYPE_FLOAT]: return false
				if not is_finite(float(value)) or float(value) != floor(float(value)): return false
				if value < spec.min or value > spec.max: return false
				value = int(value)
			"choice":
				if not value is String or value not in spec.options: return false
			"toggle":
				if not value is bool: return false
		values[key] = value
		write_probe()
		return true
	return false

func apply_live(sim: RefCounted) -> void:
	sim.boost_cost = values.boost_cost
	sim.boost_duration = 1.25 * values.boost_duration / 100.0
	sim.energy_refill = values.energy_refill / 100.0
	sim.respawn_seconds = values.respawn_seconds


func write_probe() -> void:
	# Opt-in observation for real-host integration tests. No player data.
	var path := OS.get_environment("GAMENIGHT_SETTINGS_PROBE")
	if path.is_empty(): return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"settings": values}))
