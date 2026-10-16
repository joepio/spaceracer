extends SceneTree
const Race = preload("res://src/race.gd")
const EngineAudio = preload("res://src/engine_audio.gd")
const GameAudio = preload("res://src/game_audio.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var race := Race.new([{"slot":0},{"slot":1},{"slot":2},{"slot":3}],31)
	race.countdown = 0.0
	var engine := EngineAudio.new(); root.add_child(engine)
	var cues := GameAudio.new(); root.add_child(cues)
	var camera := Camera3D.new(); root.add_child(camera)
	var views := [{"index":0,"camera":camera}]
	var p: Dictionary = race.racers[0]
	p.speed = 280.0; p.engine_power = 1.0
	for i in 120: engine.update(race,views,true,true,1.0/60.0)
	check(engine.voices.drive.playing and engine.levels.drive > .4,"Throttle produces the loaded power layer")
	check(absf(engine.voices.drive.volume_db - linear_to_db(engine.levels.drive) + 20.0) < .01,"Loaded motor is 20 dB below its original envelope")
	check(absf(engine.voices.idle.volume_db - linear_to_db(engine.levels.idle) + 18.0) < .01,"Idle bed is reduced by 18 dB")
	check(engine.voices.drive.pitch_scale >= .85 and engine.voices.drive.pitch_scale <= 1.4,"High speed stays within a restrained pitch range")
	var loaded: float = engine.levels.drive
	p.engine_power = 0.0
	for i in 120: engine.update(race,views,true,true,1.0/60.0)
	check(engine.levels.drive < loaded*.3,"Throttle lift changes timbre and power at identical road speed")
	check(engine.levels.air > .1,"Coasting retains air rush")
	check(absf(engine.voices.air.volume_db - linear_to_db(engine.levels.air) + 16.0) < .01,"Coasting air rush is reduced by 16 dB")
	p.boost = 1.0
	for i in 60: engine.update(race,views,true,true,1.0/60.0)
	check(engine.levels.boost_loop > .4,"Boost has a sustained layer")
	check(absf(engine.voices.boost_loop.volume_db - linear_to_db(engine.levels.boost_loop) + 18.0) < .01,"Sustained boost is reduced by 18 dB")
	p.emp_time = 1.0
	for i in 60: engine.update(race,views,true,true,1.0/60.0)
	check(engine.levels.boost_loop < .001 and engine.levels.drive < .001 and engine.levels.idle < .001,"EMP cuts the motor and booster")
	p.emp_time = 0.0; p.boost = 0.0; p.drone_time = 2.0; p.drone_target = 1
	for i in 60: engine.update(race,views,true,true,1.0/60.0)
	check(engine.voices.sentry.playing,"Sentry fire has a bounded loop")
	check(absf(engine.voices.sentry.volume_db - linear_to_db(engine.levels.sentry)) < .01,"Sentry action cue keeps its existing level")
	p.crashed = true
	for i in 60: engine.update(race,views,true,true,1.0/60.0)
	check(engine.levels.values().all(func(x): return x < .001),"Destroyed craft has no continuing engine or gun")
	p.crashed = false
	engine.update(race,views,true,true,.1)
	engine.update(race,views,false,true,.1)
	check(engine.voices.values().all(func(x): return not x.playing),"Pause stops all continuous audio")
	engine.update(race,views,true,false,.1)
	check(engine.voices.values().all(func(x): return not x.playing),"Mute stops all continuous audio")
	p.engine_power = 1.0; p.drone_time = 0.0
	engine.silence()
	for i in 120: engine.update(race,views,true,true,1.0/60.0)
	var solo: float = engine.levels.drive
	for i in 4:
		race.racers[i].speed = p.speed; race.racers[i].engine_power = p.engine_power
	var four := [{"index":0},{"index":1},{"index":2},{"index":3}]
	for i in 120: engine.update(race,four,true,true,1.0/60.0)
	check(absf(engine.levels.drive-solo)<.001,"Four players do not quadruple engine volume")
	check(engine.get_child_count()==6,"Continuous voice count stays fixed")
	check(engine.voices.drive.volume_db < -18.0,"Full split-screen motor remains below -18 dB")
	cues.update(race,views,true,true)
	var before: int = cues.serial
	p.flash=.18; p.energy-=8
	cues.update(race,views,true,true)
	check(cues.serial==before+1,"Rail collision produces an impact without a weapon impact ID")
	cues.clock+=1.; before=cues.serial; p.boost=1.
	cues.update(race,views,true,true); cues.update(race,views,true,true)
	check(cues.serial==before+1,"Held boost does not retrigger repeatedly")
	cues.clock+=1.; before=cues.serial; p.weapon="missile"
	cues.update(race,views,true,false); cues.update(race,views,true,true)
	check(cues.serial==before,"Muted pickup is consumed, not replayed on unmute")
	cues.clock+=1.; before=cues.serial; p.crash_id+=1
	cues.update(race,views,false,true); cues.update(race,views,true,true)
	check(cues.serial==before,"Paused changes do not create stale impact cues")
	for event in [[race.weapons.missiles,"launch"],[race.weapons.bombs,"launch"],[race.weapons.rail_shots,"rail"],[race.weapons.pulses,"emp"]]:
		cues.clock+=2.; before=cues.serial
		event[0].append({"id":cues.serial+100,"position":Vector3.ZERO})
		cues.update(race,views,true,true); cues.update(race,views,true,true)
		check(cues.serial==before+1,"New weapon event plays once: "+event[1])
		event[0].clear(); cues.update(race,views,true,true)
	check(cues.seen.is_empty(),"Expired event tracking is bounded")
	cues.clock+=2.;race.countdown=1.;cues.update(race,views,true,true);before=cues.serial
	cues.clock+=2.;race.countdown=0.;cues.update(race,views,true,true)
	check(cues.serial==before+1,"Start signal fires on countdown transition")
	check(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("RaceSound"))==1,"One shared limiter protects the mix")
	# Let the audio server consume queued play commands before destroying nodes.
	await create_timer(.25).timeout
	engine.free(); cues.free(); camera.free()
	race = null
	await create_timer(.15).timeout
	print("RACER_AUDIO_TESTS %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
