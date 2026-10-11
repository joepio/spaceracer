extends Node
## One shared cockpit mix for the viewed racers: split-screen never multiplies loudness.
const Mix = preload("res://src/race_audio_mix.gd")
const LAYERS := ["idle", "drive", "air", "boost_loop", "scrape", "sentry"]
var voices: Dictionary = {}
var levels: Dictionary = {}
var rpm := 0.0
var current_race: RefCounted

func _ready() -> void:
	Mix.ensure_bus()
	for layer in LAYERS:
		var player := AudioStreamPlayer.new()
		var clip: AudioStreamWAV = load("res://assets/audio/racer/%s.wav" % layer).duplicate()
		clip.loop_mode = AudioStreamWAV.LOOP_FORWARD
		clip.loop_begin = 0
		clip.loop_end = int(round(clip.get_length() * clip.mix_rate))
		player.stream = clip
		player.bus = Mix.BUS
		player.volume_db = -80
		add_child(player)
		voices[layer] = player
		levels[layer] = 0.0

func silence() -> void:
	for layer in LAYERS:
		voices[layer].stop()
		voices[layer].volume_db = -80
		levels[layer] = 0.0
	rpm = 0.0

func update(race: RefCounted, views: Array, running: bool, enabled: bool, dt: float, duck: float = 1.0) -> void:
	if current_race != race:
		silence()
		current_race = race
	if race == null or not running or not enabled or race.over or views.is_empty():
		silence()
		return
	var speed := 0.0
	var power := 0.0
	var boost := 0.0
	var airborne := 0.0
	var scraping := 0.0
	var firing := 0.0
	var alive := false
	var powered := false
	for view in views:
		var p: Dictionary = race.racers[view.index]
		if p.crashed or p.recovery > 0.0 or p.finished: continue
		alive = true
		speed = maxf(speed, clampf(p.speed / 430.0, 0.0, 1.0))
		airborne = maxf(airborne, 1.0 if p.airborne else 0.0)
		if p.emp_time <= 0:
			powered = true
			power = maxf(power, p.engine_power)
			boost = maxf(boost, 1.0 if p.boost > 0 or p.on_pad or p.warp_time > 0 else 0.0)
		if p.flash > .03 and not p.airborne: scraping = maxf(scraping, speed)
		if p.drone_time > 0 and p.drone_target >= 0 and p.emp_time <= 0: firing = 1.0
	var spool := clampf(power*.58 + speed*.42, 0.0, 1.0)
	rpm = lerpf(rpm, spool, 1.0-exp(-dt*(3.2 if spool > rpm else 2.0)))
	var targets := {
		"idle": (.13 + power*.08)*(1.0-speed*.55) if powered else 0.0,
		"drive": (.10 + power*.52)*smoothstep(.02,.4,rpm) if powered else 0.0,
		"air": pow(speed,1.5)*(.34+airborne*.12),
		"boost_loop": boost*.44,
		"scrape": scraping*.22,
		"sentry": firing*.6,
	}
	if not alive:
		for layer in LAYERS: targets[layer] = 0.0
	for layer in LAYERS:
		var player: AudioStreamPlayer = voices[layer]
		var target: float = targets[layer] * (duck if layer != "sentry" else 1.0)
		var rate := 8.0 if target > levels[layer] else 12.0
		levels[layer] = lerpf(levels[layer], target, 1.0-exp(-dt*rate))
		if levels[layer] < .0005:
			player.stop()
			player.volume_db = -80
			continue
		player.pitch_scale = (.88 + rpm*.48) if layer == "idle" else ((.85 + rpm*.55) if layer == "drive" else (1.0+speed*.12 if layer in ["air","boost_loop"] else 1.0))
		player.volume_db = linear_to_db(levels[layer]) + Mix.ENGINE_TRIM_DB.get(layer, 0.0)
		if not player.playing: player.play()

func _exit_tree() -> void:
	silence()
	for player in voices.values(): player.stream = null
	current_race = null
