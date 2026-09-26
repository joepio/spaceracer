extends "res://addons/gamenight/gamenight.gd"
## The vendored SDK provides WebSocket transport. This adapter implements the
## current contract: host input, session guards, no focus-driven transitions.
signal roster_changed(seats: Array, players: Array, presence: Array)
var session := ""
var phase := "idle"
var frames: Dictionary = {}
var frame_at := -10000
var connected_at := 0

func _ready() -> void:
	game_id = "ion-rush"
	launched_by_daemon = OS.get_environment("GAMENIGHT") == "1"
	auto_reconnect = false
	connected_at = Time.get_ticks_msec()
	if launched_by_daemon:
		super._ready()

func _process(delta: float) -> void:
	if not launched_by_daemon:
		return
	super._process(delta)
	if _socket == null or (not _said_hello and Time.get_ticks_msec() - connected_at > 10000):
		get_tree().quit()

func _unhandled_input(_event: InputEvent) -> void:
	pass # Main owns a release-gated Back action, including authoritative host input.

func _handle(msg: Variant) -> void:
	if not msg is Dictionary:
		return
	var kind: String = msg.get("type", "")
	if kind == "welcome":
		if msg.get("protocol_version", 0) != 1:
			get_tree().quit(1)
			return
		super._handle(msg)
	elif kind == "controller_frame":
		frames.clear()
		frame_at = Time.get_ticks_msec()
		for frame in msg.get("controllers", []):
			var token: String = frame.get("controller", "")
			if not token.is_empty() and not frames.has(token):
				frames[token] = frame
	elif kind == "prepare":
		if msg.get("game", "") != game_id or msg.get("session", "") == session:
			return
		if not session.is_empty():
			disposed.emit(session)
		session = msg.get("session", "")
		phase = "preparing"
		prepared.emit(session, msg.get("seats", []), msg.get("players", []))
	elif kind == "setting_changed" or kind == "error":
		super._handle(msg)
	elif not session.is_empty() and msg.get("session", "") == session:
		match kind:
			"start":
				if phase == "ready":
					phase = "running"
					started.emit(session)
			"pause":
				if phase == "running":
					phase = "paused"
					paused.emit(session)
			"resume":
				if phase == "paused":
					phase = "running"
					resumed.emit(session)
			"dispose":
				disposed.emit(session)
				session = ""
				phase = "idle"
				frames.clear()
			"party_updated":
				roster_changed.emit(msg.get("seats", []), msg.get("players", []), msg.get("presence", []))

func ready_for_session(value: String) -> void:
	if session != value or phase != "preparing":
		return
	_send({"type": "participation", "session": session, "instant_join": false})
	phase = "ready"
	notify_ready(session)

func frame(token: String) -> Dictionary:
	if Time.get_ticks_msec() - frame_at >= 250:
		return {}
	return frames.get(token, {})

static func pressed(value: Dictionary, index: int) -> bool:
	return (int(value.get("buttons", 0)) & (1 << index)) != 0

static func axis(value: Dictionary, index: int) -> float:
	var axes: Array = value.get("axes", [])
	return clampf(float(axes[index]) / 32767, -1, 1) if axes.size() > index else 0.0

func controls(token: String) -> Dictionary:
	var value := frame(token)
	var steer := axis(value, 0)
	steer = signf(steer) * maxf(0, (absf(steer) - .15) / .85)
	if pressed(value, 12): steer = -1
	if pressed(value, 13): steer = 1
	return {"steer": steer, "throttle": maxf(axis(value, 5), 1.0 if pressed(value, 0) else 0.0),
		"strafe": signf(axis(value,2))*maxf(0,(absf(axis(value,2))-.15)/.85),
		"trim": -signf(axis(value,3))*maxf(0,(absf(axis(value,3))-.15)/.85),
		"brake": maxf(float(pressed(value,2)),clampf((axis(value,4)-.06)/.94,0,1)), "boost": pressed(value, 1),
		"left": pressed(value, 4), "right": pressed(value, 5),"reset":pressed(value,3)}
