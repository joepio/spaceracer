extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var bank = load("res://src/game_audio.gd").new()
	root.add_child(bank)
	check(bank.voices.size()==10, "Voice count bounded")
	for family in bank.streams:
		var last := -1
		for cycle in 4:
			var seen := {}
			for i in 5:
				var take: int = bank.next_take(family)
				check(take != last, "No adjacent duplicate at shuffle boundaries")
				seen[take] = true; last = take
			check(seen.size()==5, "Every take occurs once per shuffle cycle")
		for stream in bank.streams[family]:
			check(stream != null and stream.get_length() > .01, "Playable clip loaded")
	for cue in bank.cues:
		bank.clock += 2.0
		var before: int = bank.serial
		bank.play_cue(cue); bank.play_cue(cue)
		check(bank.serial==before+1, "Per-cue cooldown stops chatter")
	bank.set_active(false)
	var before: int = bank.serial
	for cue in bank.cues: bank.play_cue(cue)
	check(bank.serial==before, "Muted bank cannot start sounds")
	bank.set_active(true,true)
	for cue in bank.cues: bank.play_cue(cue)
	check(bank.serial==before, "Paused bank cannot start sounds")
	bank.set_active(true)
	bank.clock += 2.0
	bank.play_cue(bank.cues.keys()[0])
	check(bank.serial==before+1, "Bank resumes after pause")
	check(bank.get_child_count()==10, "Hot path creates no extra players")
	# Let the audio server consume queued play commands before destroying nodes.
	await create_timer(.25).timeout
	bank.free()
	await create_timer(.15).timeout
	print("Audio bank: ",failures," failures")
	quit(failures)
