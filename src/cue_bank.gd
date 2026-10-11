extends Node
const Mix = preload("res://src/race_audio_mix.gd")
## Cached recorded takes, bounded voices, independent cosmetic RNG.
var cues: Dictionary = {}
var streams: Dictionary = {}
var bags: Dictionary = {}
var previous: Dictionary = {}
var cooldown: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var rng := RandomNumberGenerator.new()
var active := true
var paused := false
var clock := 0.0
var serial := 0

func configure(definitions: Dictionary) -> void:
	Mix.ensure_bus()
	cues = definitions
	rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for spec in cues.values():
		var family: String = spec[0]
		if streams.has(family): continue
		streams[family] = []
		for i in 5:
			streams[family].append(load("res://assets/audio/racer/%s_%d.wav" % [family, i+1]))
	for i in 10:
		var voice := AudioStreamPlayer.new()
		voice.set_meta("serial", -1)
		voice.bus = Mix.BUS
		add_child(voice)
		voices.append(voice)

func _process(delta: float) -> void:
	if not paused: clock += delta

func set_active(enabled: bool, pause_audio: bool = false) -> void:
	active = enabled
	paused = pause_audio
	for voice in voices:
		voice.stream_paused = paused
		if not active: voice.stop()
	if not active: cooldown.clear()

func next_take(family: String) -> int:
	var bag: Array = bags.get(family, [])
	if bag.is_empty():
		bag = [0, 1, 2, 3, 4]
		for i in range(4, 0, -1):
			var j := rng.randi_range(0, i)
			var value = bag[i]; bag[i] = bag[j]; bag[j] = value
		if bag.back() == previous.get(family, -1):
			var value = bag[0]; bag[0] = bag[4]; bag[4] = value
	var take: int = bag.pop_back()
	bags[family] = bag
	previous[family] = take
	return take

func play_cue(cue: String, strength: float = 1.0) -> void:
	if not active or paused or not cues.has(cue): return
	var spec: Array = cues[cue]
	if clock < float(cooldown.get(cue, -1.0)): return
	cooldown[cue] = clock + float(spec[2])
	# Two reserved voices keep round/success cues clear during contact bursts.
	var first: int = 8 if spec[4] else 0
	var last: int = 10 if spec[4] else 8
	var voice := voices[first]
	for i in range(first, last):
		if not voices[i].playing:
			voice = voices[i]; break
		if int(voices[i].get_meta("serial")) < int(voice.get_meta("serial")): voice = voices[i]
	voice.stop()
	voice.stream = streams[spec[0]][next_take(spec[0])]
	voice.pitch_scale = float(spec[3]) * rng.randf_range(.97, 1.03)
	voice.volume_db = float(spec[1]) + linear_to_db(clampf(strength, .15, 1.15))
	serial += 1
	voice.set_meta("serial", serial)
	voice.play()

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	streams.clear()
	voices.clear()
