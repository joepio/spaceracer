extends SceneTree
var game:Node
var failures:=0

func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")

func check(value:bool,message:String)->void:
	if not value:
		failures+=1
		push_error(message)

func focus_id()->String:
	var focused:=root.gui_get_focus_owner()
	return str(focused.get_meta("menu_id","")) if focused else ""

func stick(x:float,y:float)->void:
	for axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
		var neutral:=InputEventJoypadMotion.new()
		neutral.axis=axis
		neutral.axis_value=0
		Input.parse_input_event(neutral)
	await process_frame
	for pair in [[JOY_AXIS_LEFT_X,x],[JOY_AXIS_LEFT_Y,y]]:
		var event:=InputEventJoypadMotion.new()
		event.axis=pair[0]
		event.axis_value=pair[1]
		Input.parse_input_event(event)
	await process_frame
	await process_frame

func press(button:int)->void:
	var event:=InputEventJoypadButton.new()
	event.button_index=button
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=InputEventJoypadButton.new()
	event.button_index=button
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame

func run()->void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(focus_id()=="race","Race focused initially")
	check(game.seed_input.text.length()==5 and int(game.seed_input.text)==game.race.track.seed_value,"Menu shows a short code for the preview track")
	await stick(0,-.9)
	check(focus_id()=="seed","Analog up reaches seed")
	await stick(.9,0)
	await stick(0,0)
	var old_seed:int=game.selected_seed
	check(focus_id()=="random","Analog right reaches Random")
	await press(JOY_BUTTON_A)
	check(game.selected_seed!=old_seed and game.seed_input.text.length()==5 and focus_id()=="random","Random chooses another short code without losing focus")
	await stick(0,-.9)
	check(focus_id()=="player1","Analog up reaches player row")
	await stick(.9,0)
	check(focus_id()=="player2","Analog right changes focus")
	await stick(0,0)
	await press(JOY_BUTTON_A)
	check(game.human_count==2 and focus_id()=="player2","A selects player count and preserves focus")
	await stick(-.9,0)
	await stick(0,0)
	await press(JOY_BUTTON_A)
	check(game.human_count==1,"Analog left and A select solo")
	await stick(0,.9)
	check(focus_id()=="seed","Down reaches seed field")
	await stick(0,0)
	await press(JOY_BUTTON_A)
	check(game.in_menu,"A on seed field does not accidentally launch")
	for digit in "00421":
		var key:=InputEventKey.new()
		key.keycode=digit.unicode_at(0)
		key.unicode=digit.unicode_at(0)
		key.pressed=true
		Input.parse_input_event(key)
		await process_frame
		key=key.duplicate()
		key.pressed=false
		Input.parse_input_event(key)
	check(game.selected_seed==421,"Typing a code updates selected seed")
	await stick(0,.9)
	check(focus_id()=="race" and game.seed_input.text=="00421","Down reaches Race and keeps the short code")
	await stick(0,.9)
	check(focus_id()=="controls","Down reaches Controls")
	await stick(.9,0)
	await stick(0,0)
	check(focus_id()=="graphics","Right reaches Graphics")
	await press(JOY_BUTTON_A)
	check(game.quality==.6 and focus_id()=="graphics","A changes graphics without losing focus")
	await press(JOY_BUTTON_START)
	check(game.running and not game.in_menu and game.views.size()==1,"Start launches selected solo race from any menu button")
	check(game.race.track.seed_value==421,"Start launches exactly the displayed seed, without incrementing it")
	check(not game.race.racers[0].bot,"Solo launch gives the player control")
	check(AudioServer.is_bus_mute(0),"Playtest stays muted")
	var saved_nodes:Array=game.race.track.nodes.duplicate(true)
	game.running=false
	game.in_menu=true
	game.make_menu()
	check(game.seed_input.text=="00421","Returning to menu preserves the current track code")
	game.seed_input.text="00000"
	game.seed_input.text_changed.emit("00000")
	game.finish_seed_edit()
	check(game.seed_input.text=="00421","Zero/empty entry restores the last valid code")
	await press(JOY_BUTTON_START)
	check(game.race.track.nodes==saved_nodes,"Replaying a written code recreates the exact circuit")
	game.next_seed=99999
	game.new_race()
	check(game.race.track.seed_value==99999 and game.next_seed==1,"Automatic next-track seeds wrap within five digits")
	print("MENU_TESTS ",failures," failures")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
