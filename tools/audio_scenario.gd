extends SceneTree
## Record a scripted stretch of real gameplay through the game's own audio mix,
## for tools/audio_judge.py. Countdown and launch, full throttle, a boost, a
## brake, then each weapon in turn, with three bots racing alongside.
##   godot --headless --path . --script res://tools/audio_scenario.gd [-- --out=build/audio-loop/run]
## Writes <out>.wav and <out>.json (event markers in seconds).
const SCRIPT:=[
	# [start second, label, input/setup]
	[0.,"countdown",{}],
	[2.2,"rev",{"throttle":1.}],
	[3.,"launch",{"throttle":1.}],
	[9.,"boost",{"throttle":1.,"boost":true}],
	[11.5,"cruise",{"throttle":1.}],
	[13.,"brake",{"brake":1.}],
	[14.,"coast",{}],
	[15.,"missile",{"throttle":1.,"weapon":"missile"}],
	[18.5,"railgun",{"throttle":1.,"weapon":"railgun"}],
	[22.,"sentry",{"throttle":1.,"weapon":"drone"}],
	[26.,"emp",{"throttle":1.,"weapon":"emp"}],
	[29.5,"warp",{"throttle":1.,"weapon":"warp"}],
	[33.,"bomb",{"throttle":1.,"weapon":"bomb","trim":-1.}],
	[36.5,"end",{"throttle":1.}],
]
const LENGTH:=38.
var game:Node
var recorder:AudioEffectRecord
var clock:=0.
var section:=-1
var events:Array=[]
var out:="res://build/audio-loop/run"
var done:=false
var fired:={}

func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out="res://"+arg.get_slice("=",1)
	call_deferred("start")

func start()->void:
	root.unfocusable=true
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.settings.values.bots=3
	game.human_count=1;game.biome="city";game.difficulty="normal";game.next_seed=31;game.start_local()
	game.set_physics_process(false)
	game.race.racers[0].bot=false
	game.sound_enabled=true;AudioServer.set_bus_mute(0,false)
	recorder=AudioEffectRecord.new()
	AudioServer.add_bus_effect(0,recorder)
	recorder.set_recording_active(true)

func _physics_process(dt:float)->bool:
	if game==null or game.race==null or recorder==null or done: return false
	clock+=dt
	var race:RefCounted=game.race
	var p:Dictionary=race.racers[0]
	while section+1<SCRIPT.size() and clock>=SCRIPT[section+1][0]:
		section+=1
		var spec:Dictionary=SCRIPT[section][2]
		events.append({"t":SCRIPT[section][0],"label":SCRIPT[section][1]})
		if spec.get("boost",false): p.lap=maxi(p.lap,2);p.energy=100. # boost unlocks on lap two
		if spec.has("weapon"):
			p.weapon=spec.weapon;p.weapon_acquired=race.clock;p.energy=maxf(p.energy,80.)
			# Put two rivals just ahead so every weapon has something to hit.
			for i in [1,2]:
				var rival:Dictionary=race.racers[i]
				if rival.airborne or rival.crashed: continue
				rival.distance=p.distance+120.+i*70.;rival.x=p.x+(i-1.5)*6.;rival.speed=p.speed*.95
	var spec:Dictionary=SCRIPT[section][2]
	var mine:={"steer":0.,"throttle":float(spec.get("throttle",0.)),"brake":float(spec.get("brake",0.)),"boost":spec.get("boost",false) and fmod(clock-SCRIPT[section][0],1.3)<.2,
		"fire":spec.has("weapon") and fmod(clock-SCRIPT[section][0],1.)<.15 and p.weapon!="","trim":float(spec.get("trim",0.)) if not p.airborne else 0.,"strafe":0.}
	# Hold the racing line: steer like a bot, but with the scripted pedals and buttons.
	var line:Dictionary=race.bot(p)
	if not line.is_empty(): mine.steer=line.steer;mine.strafe=line.strafe
	if p.airborne and not line.is_empty():
		var fire:bool=mine.fire
		mine.merge(line,true);mine.fire=fire
	var inputs:Array=[mine]
	for i in range(1,race.racers.size()): inputs.append(race.bot(race.racers[i]))
	var boosting:bool=p.boost>0.
	race.step(dt,inputs)
	if p.boost>0. and not boosting: events.append({"t":snappedf(clock,.01),"label":"fired_boost"})
	for kind in ["missiles","bombs","rail_shots","pulses"]:
		var count:int=race.weapons.get(kind).size()
		if count>int(fired.get(kind,0)): events.append({"t":snappedf(clock,.01),"label":"fired_"+kind})
		fired[kind]=count
	if clock>=LENGTH: finish()
	return false

func finish()->void:
	done=true
	recorder.set_recording_active(false)
	var recording:=recorder.get_recording()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	var error:=recording.save_to_wav(out+".wav")
	var file:=FileAccess.open(out+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"seconds":recording.get_length(),"events":events,"audio_version":preload("res://src/race_audio_mix.gd").VERSION}," "))
	file.close()
	print("AUDIO_SCENARIO ",ProjectSettings.globalize_path(out+".wav")," seconds ",recording.get_length()," result ",error)
	game.queue_free()
	await create_timer(.2).timeout
	quit(error)
