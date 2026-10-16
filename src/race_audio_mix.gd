extends RefCounted
const BUS := &"RaceSound"
const VERSION := "turbine-quiet-2026-10-16"
# Continuous cockpit beds sit below weapon, impact and race cues. Keep these
# trims separate from throttle envelopes so the motor still responds naturally.
const ENGINE_TRIM_DB := {"idle": -18.0, "drive": -20.0, "air": -16.0, "boost_loop": -18.0}
static func ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0: return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, &"Master")
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -2.0
	limiter.release = .12
	AudioServer.add_bus_effect(index, limiter)
