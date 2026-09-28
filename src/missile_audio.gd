extends Node
## Cached procedural blast: sharp noise transient, falling bass and rumble tail.
var voices:Array[AudioStreamPlayer]=[]
var current_race:RefCounted
var heard:Dictionary={}
var stream:AudioStreamWAV

static func synthesize()->AudioStreamWAV:
	var rng:=RandomNumberGenerator.new();rng.seed=3917
	var data:=PackedByteArray();var sample_rate:=22050;var count:=int(sample_rate*1.8)
	data.resize(count*2)
	var low:=0.;var phase:=0.
	for i in range(count):
		var t:=float(i)/sample_rate
		var noise:=rng.randf_range(-1.,1.);low=lerpf(low,noise,.018)
		phase+=TAU*(38.+100.*exp(-t*26.))/sample_rate
		var value:=noise*exp(-t*32.)*.65+sin(phase)*exp(-t*5.)*.36+low*exp(-t*1.8)*2.4
		value*=minf(1.,t*1500.)*smoothstep(1.8,1.55,t)
		data.encode_s16(i*2,int(tanh(value)*26000.))
	var result:=AudioStreamWAV.new();result.mix_rate=sample_rate;result.format=AudioStreamWAV.FORMAT_16_BITS;result.data=data
	return result

func _ready()->void:
	for i in range(4):
		var voice:=AudioStreamPlayer.new();add_child(voice);voices.append(voice)

func update(race:RefCounted,views:Array,running:bool,enabled:bool)->void:
	# Warm the sample when audio is enabled, before the first impact.
	if enabled and stream==null: stream=synthesize()
	if current_race!=race:
		current_race=race;heard.clear()
		for voice in voices: voice.stop()
	for voice in voices:
		voice.stream_paused=not running
		if not enabled: voice.stop()
	if race==null or not running: return
	for burst in race.weapons.bursts:
		var id:int=burst.get("id",-1)
		if heard.has(id): continue
		heard[id]=true
		if not enabled: continue
		var distance:=INF
		for view in views: distance=minf(distance,view.camera.global_position.distance_to(burst.position))
		if distance>600.: continue
		var voice:=voices[id%voices.size()]
		voice.pitch_scale=.7 if burst.get("size",14.)>30. else 1.
		voice.stream=stream;voice.volume_db=-8.-20.*log(maxf(1.,distance/40.))/log(10.)
		voice.play()

func _exit_tree()->void:
	for voice in voices:
		voice.stop();voice.stream=null
	stream=null;current_race=null
