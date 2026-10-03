extends SceneTree
const Settings = preload("res://src/settings.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func validate(settings: RefCounted) -> void:
	for spec in settings.SPECS:
		var invalid: Array = [null, {}, []]
		if spec.kind == "number":
			check(settings.change(spec.key, float(spec.min)), "JSON integral numbers accepted")
			check(settings.change(spec.key, spec.max), "Upper boundary accepted")
			invalid += [true, "10", 1.5, INF, NAN, spec.min-1, spec.max+1]
		elif spec.kind == "choice":
			for option in spec.options: check(settings.change(spec.key,option),"Choice accepted")
			invalid += ["unknown", 1, false]
		else:
			check(settings.change(spec.key, not spec.default), "Toggle accepted")
			invalid += ["false", 0, 1]
		check(settings.change(spec.key, spec.default), "Reset accepted")
		for value in invalid:
			check(not settings.change(spec.key,value), "Invalid value rejected: "+spec.key)
			check(settings.values[spec.key] == spec.default, "Invalid update preserves value")
	check(not settings.change("controller_id", 1), "Roster cannot be changed via settings")
func finish(settings: RefCounted) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settings-output="):
			var file = FileAccess.open(arg.trim_prefix("--settings-output="), FileAccess.WRITE)
			file.store_string(JSON.stringify(settings.SPECS))
	print("SETTINGS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

const Race = preload("res://src/race.gd")
func run() -> void:
	var settings = Settings.new()
	validate(settings)
	var race = Race.new([{"slot":0}],31)
	settings.apply_live(race)
	var p: Dictionary = race.racers[0]
	p.energy=50.;p.energy_previous=50.;p.energy_refill_delay=0.
	Race.refill_energy(p,2.,race.energy_refill)
	check(p.energy==53., "Default regeneration preserved")
	settings.change("energy_refill",200);settings.apply_live(race)
	Race.refill_energy(p,2.,race.energy_refill)
	check(p.energy==59., "Regeneration doubles in existing race")
	settings.change("energy_refill",0);settings.apply_live(race)
	Race.refill_energy(p,2.,race.energy_refill)
	check(p.energy==59., "Regeneration can be disabled")
	race.countdown=0.;p.lap=2;p.energy=100.;p.energy_previous=100.
	settings.change("boost_cost",40);settings.change("boost_duration",200);settings.apply_live(race)
	race.step(.01,[{"boost":true}])
	check(is_equal_approx(p.energy,60.), "Actual boost consumes configured energy")
	check(p.boost>2.4, "Actual boost uses configured duration")
	settings.change("boost_duration",50);settings.apply_live(race)
	check(p.boost>2.4, "Existing boost is not truncated")
	finish(settings)
