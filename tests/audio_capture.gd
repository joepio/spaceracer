extends SceneTree
## Capture a reproducible controller sequence through the real audio nodes and bus.
const Race = preload("res://src/race.gd")
const EngineAudio = preload("res://src/engine_audio.gd")
const GameAudio = preload("res://src/game_audio.gd")
const MissileAudio = preload("res://src/missile_audio.gd")
var race: RefCounted
var engine: Node
var cues: Node
var missiles: Node
var old_engine: AudioStreamPlayer
var camera: Camera3D
var recorder: AudioEffectRecord
var clock := 0.0
var step := -1
var before := false
var finished := false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	before = "--before" in OS.get_cmdline_user_args()
	race=Race.new([{"slot":0}],31);race.countdown=0.0
	engine=EngineAudio.new();root.add_child(engine)
	cues=GameAudio.new();root.add_child(cues)
	missiles=MissileAudio.new();root.add_child(missiles)
	camera=Camera3D.new();root.add_child(camera)
	recorder=AudioEffectRecord.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("RaceSound"),recorder)
	# Capture upstream of Master mute so preview generation doesn't play aloud.
	AudioServer.set_bus_mute(0,true)
	if before:
		old_engine=AudioStreamPlayer.new();old_engine.bus="RaceSound"
		var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=22050
		var data:=PackedByteArray();data.resize(44100)
		for i in 22050:
			var t:=float(i)/22050
			data.encode_s16(i*2,int((sin(TAU*55*t)*.45+sin(TAU*110*t)*.2+sin(TAU*165*t)*.1)*12000))
		wav.data=data;wav.loop_mode=AudioStreamWAV.LOOP_FORWARD;wav.loop_end=22050
		old_engine.stream=wav;root.add_child(old_engine);old_engine.play()
	recorder.set_recording_active(true)
func _process(dt: float) -> bool:
	if recorder==null or finished: return false
	clock+=dt
	var p:Dictionary=race.racers[0]
	var section:=int(clock/3.0)
	var speed:=0.0
	var throttle:=0.0
	match section:
		0: throttle=.12;speed=20.
		1: throttle=1.;speed=lerpf(20.,300.,fmod(clock,3.)/3.)
		2: throttle=1.;speed=300.
		3: throttle=0.;speed=280.
		4: throttle=1.;speed=430.
		5: throttle=1.;speed=270.
		6: throttle=0.;speed=80.
	p.speed=speed;p.engine_power=throttle;p.boost=1. if section==4 else 0.
	p.airborne=section==3
	if section!=step:
		if section==5: p.flash=.18;p.energy-=18
		if section==6:
			p.crash_id+=1;p.crashed=true
		step=section
	p.flash=maxf(0.,p.flash-dt)
	var views:=[{"index":0,"camera":camera}]
	if before:
		old_engine.pitch_scale=.65+speed/130.
		old_engine.volume_db=-28+speed/80.
	else:
		cues.update(race,views,true,true)
		missiles.update(race,views,true,true)
		engine.update(race,views,true,true,dt,cues.engine_duck())
	if clock>=21.:
		finished=true
		recorder.set_recording_active(false)
		var recording:=recorder.get_recording()
		var path:="res://build/audio-redesign/%s.wav" % ("before" if before else "after")
		DirAccess.make_dir_recursive_absolute("res://build/audio-redesign")
		var error:=recording.save_to_wav(path)
		print("AUDIO_CAPTURE ",path," seconds ",recording.get_length()," result ",error)
		finish.call_deferred(error)
	return false
func finish(error: int) -> void:
	engine.free();cues.free();missiles.free();camera.free()
	if is_instance_valid(old_engine):old_engine.stop();old_engine.stream=null;old_engine.free()
	race=null
	await create_timer(.2).timeout
	quit(error)
