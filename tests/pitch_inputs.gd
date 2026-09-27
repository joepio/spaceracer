extends SceneTree
const Bridge=preload("res://src/bridge.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func run()->void:
	var bridge:=Bridge.new();root.add_child(bridge)
	for axes in [[0,-32767,0,0,0,0],[0,0,0,-32767,0,0],[0,-32767,0,-32767,0,0]]:
		bridge._handle({"type":"controller_frame","controllers":[{"controller":"pilot","axes":axes,"buttons":0}]})
		check(bridge.controls("pilot").trim==1.,"Either stick forward gives full grip without doubling")
	bridge._handle({"type":"controller_frame","controllers":[{"controller":"pilot","axes":[0,32767,0,0,0,0],"buttons":0}]})
	check(bridge.controls("pilot").trim==-1.,"Left stick back lifts the nose")
	check(Bridge.pitch_axis(.1,-.1)==0.,"Resting-stick noise remains in the dead zone")
	check(Bridge.pitch_axis(.8,-.2)<-.7 and Bridge.pitch_axis(-.2,.8)<-.7,"Strong input on either stick wins over a weaker opposing input")
	check(Bridge.pitch_axis(.5,.5)==Bridge.pitch_axis(0.,.5),"Combined sticks retain analog response")
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	var devices:=Input.get_connected_joypads()
	# Native controller polling can only be exercised with a connected device.
	var device:int=devices[0] if not devices.is_empty() else -1
	var pilot:Dictionary={"slot":0,"device":device}
	for axes in [[-1.,0.],[0.,-1.],[1.,0.],[0.,1.]]:
		if device<0: break
		for axis in [JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_Y]:
			var event:=InputEventJoypadMotion.new();event.device=device;event.axis=axis;event.axis_value=axes[0 if axis==JOY_AXIS_LEFT_Y else 1]
			Input.parse_input_event(event)
		Input.flush_buffered_events()
		check(game.controls(pilot).trim==Bridge.pitch_axis(axes[0],axes[1]),"Native controller matches GameNight pitch routing")
	if device>=0:
		for axis in [JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_Y]:
			var neutral:=InputEventJoypadMotion.new();neutral.device=device;neutral.axis=axis;neutral.axis_value=0.
			Input.parse_input_event(neutral)
	print("PITCH_NATIVE_DEVICE ",device)
	game.queue_free();bridge.queue_free();await process_frame
	print("PITCH_INPUT_TESTS ",failures," failures")
	quit(1 if failures else 0)
