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
	check(focus_id()=="race","Down reaches Race")
	await stick(0,.9)
	check(focus_id()=="controls","Down reaches Controls")
	await stick(.9,0)
	await stick(0,0)
	check(focus_id()=="graphics","Right reaches Graphics")
	await press(JOY_BUTTON_A)
	check(game.quality==.6 and focus_id()=="graphics","A changes graphics without losing focus")
	await press(JOY_BUTTON_START)
	check(game.running and not game.in_menu and game.views.size()==1,"Start launches selected solo race from any menu button")
	check(not game.race.racers[0].bot,"Solo launch gives the player control")
	check(AudioServer.is_bus_mute(0),"Playtest stays muted")
	print("MENU_TESTS ",failures," failures")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
