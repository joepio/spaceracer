extends Node
## Cached material transients, bass and debris tails; positional attenuation.
var voices:Array[AudioStreamPlayer]=[]
var current_race:RefCounted
var heard:Dictionary={}
var stream:AudioStreamWAV

var variants: Array[AudioStreamWAV] = []
var cursor := -1
var rng := RandomNumberGenerator.new()
const Mix = preload("res://src/race_audio_mix.gd")

static func synthesize(variant: int = 0) -> AudioStreamWAV:
	return load("res://assets/audio/racer/explosion_%d.wav" % (variant+1))

func _ready()->void:
	Mix.ensure_bus(); rng.randomize()
	for i in 5: variants.append(synthesize(i))
	for i in range(4):
		var voice:=AudioStreamPlayer.new();voice.bus=Mix.BUS;add_child(voice);voices.append(voice)

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
	var live_ids:Dictionary={}
	for burst in race.weapons.bursts:
		var id:int=burst.get("id",-1)
		live_ids[id]=true
		if heard.has(id): continue
		heard[id]=true
		if not enabled: continue
		var distance:=INF
		for view in views: distance=minf(distance,view.camera.global_position.distance_to(burst.position))
		if distance>600.: continue
		var voice:=voices[id%voices.size()]
		cursor=(cursor+rng.randi_range(1,4))%5
		voice.pitch_scale=.88 if burst.get("size",14.)>30. else 1.
		stream=variants[cursor]
		voice.stream=stream;voice.volume_db=-2.-20.*log(maxf(1.,distance/40.))/log(10.)
		voice.play()
	heard=live_ids

func _exit_tree()->void:
	for voice in voices:
		voice.stop();voice.stream=null
	stream=null;variants.clear();current_race=null
