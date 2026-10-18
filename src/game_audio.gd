extends "res://src/cue_bank.gd"
var current_race: RefCounted
var snapshots: Dictionary = {}
var seen: Dictionary = {}
var previous_countdown := -1
var duck_until := 0.0

func _ready() -> void:
	configure({
		"contact": ["contact", -5.0, .12, 1.0, false],
		"crash": ["explosion", -2.0, .3, .92, false],
		"boost": ["boost", -15.0, .45, 1.0, false],
		"land": ["land", -4.0, .2, 1.0, false],
		"pickup": ["pickup", -4.0, .25, 1.0, true],
		"lap": ["lap", -2.0, 1.0, 1.0, true],
		"finish": ["finish", -1.0, 2.0, 1.0, true],
		"launch": ["launch", -5.0, .12, 1.0, false],
		"rail": ["rail", -3.0, .12, 1.0, false],
		"emp": ["emp", -4.0, .35, 1.0, false],
		"warp": ["warp", -6.0, .5, 1.0, false],
		"tick": ["tick", -9.0, .5, 1.0, true],
		"go": ["go", -7.0, 1.0, 1.0, true],
		"warning": ["warning", -6.0, 1.2, 1.0, true],
	})

func engine_duck() -> float: return .65 if clock < duck_until else 1.0

func update(race: RefCounted, views: Array, running: bool, enabled: bool) -> void:
	set_active(enabled, not running)
	if current_race != race:
		current_race = race
		snapshots.clear(); seen.clear(); cooldown.clear()
		previous_countdown = -1; duck_until = 0.0
		for voice in voices: voice.stop()
	if race == null: return
	var audible: bool = running and enabled and not race.over
	var count := maxi(0, ceili(race.countdown))
	if audible and previous_countdown >= 0 and count != previous_countdown:
		if count == 0: play_cue("go")
		elif count <= 3: play_cue("tick")
	previous_countdown = count
	for view in views:
		var p: Dictionary = race.racers[view.index]
		var old: Dictionary = snapshots.get(view.index, {})
		var boosted: bool = p.boost > 0 or p.on_pad
		if audible and not old.is_empty():
			if p.crash_id != old.crash:
				play_cue("crash"); duck_until = clock+.45
			elif p.impact_id != old.impact or (p.flash > .03 and p.energy < old.energy-.15):
				play_cue("contact", clampf((old.energy-p.energy)/12.0, .3, 1.0)); duck_until = clock+.12
			if boosted and not old.boosted: play_cue("boost")
			if old.airborne and not p.airborne and not p.crashed: play_cue("land")
			if (p.weapon != "" and p.weapon != old.weapon) or p.energy_fx > old.energy_fx+.1: play_cue("pickup")
			if p.finished and not old.finished:
				play_cue("finish"); duck_until = clock+.65
			elif p.lap > old.lap: play_cue("lap")
			if p.warp_time > old.warp+.1: play_cue("warp")
			if p.emp_time > old.emp+.1: play_cue("emp")
			if p.missile_warning > .01: play_cue("warning")
		snapshots[view.index] = {"crash":p.crash_id,"impact":p.impact_id,"energy":p.energy,"boosted":boosted,"airborne":p.airborne,"weapon":p.weapon,"energy_fx":p.energy_fx,"finished":p.finished,"lap":p.lap,"warp":p.warp_time,"emp":p.emp_time}
	# Consume event IDs while muted/paused too, preventing a burst on resume.
	var live := {}
	for spec in [[race.weapons.missiles,"launch"],[race.weapons.bombs,"launch"],[race.weapons.rail_shots,"rail"],[race.weapons.pulses,"emp"]]:
		for event in spec[0]:
			var key := "%s:%s" % [spec[1],event.id]
			live[key] = true
			if seen.has(key) or not audible: continue
			var position: Vector3 = event.get("position", event.get("from", Vector3.ZERO))
			if event.has("frame"): position = event.frame.origin
			var distance := INF
			for view in views:
				if view.has("camera"): distance = minf(distance, view.camera.global_position.distance_to(position))
			if distance < 220:
				play_cue(spec[1],clampf(1.0-distance/260.0,.18,1.0))
	seen = live

func _exit_tree() -> void:
	super._exit_tree()
	current_race = null
	snapshots.clear(); seen.clear()
