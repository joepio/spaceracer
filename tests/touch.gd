extends SceneTree
var failures:=0
var pad:Control

func _initialize()->void:
	call_deferred("run")

func check(ok:bool,message:String)->void:
	if not ok:
		failures+=1
		push_error(message)

func touch(index:int,id:String,pressed:bool=true,offset:Vector2=Vector2.ZERO)->void:
	var event:=InputEventScreenTouch.new()
	event.index=index
	event.position=pad.centers()[id]+offset
	event.pressed=pressed
	pad._input(event)

func run()->void:
	pad=load("res://src/touch_controls.gd").new()
	root.add_child(pad)
	pad.size=Vector2(1600,1000)
	await process_frame
	touch(0,"throttle")
	touch(0,"throttle",false)
	check(pad.controls().throttle==1.,"Throttle stays engaged without occupying a finger")
	touch(1,"steer",true,Vector2(82,0))
	touch(2,"flight",true,Vector2(-41,41))
	check(pad.controls().steer==1. and pad.controls().strafe==-.5 and pad.controls().trim==-.5,"Two sticks maintain conventional independent axes")
	touch(7,"left")
	check(pad.controls().left and not pad.controls().right and pad.controls().strafe==-.5,"Left bump is independent of analog strafe")
	touch(7,"left",false)
	touch(7,"right")
	check(pad.controls().right and not pad.controls().left,"Both bump directions work on touch")
	touch(7,"right",false)
	touch(3,"brake")
	touch(4,"boost")
	pad.weapon_available=true
	touch(6,"fire")
	check(pad.controls().fire and pad.controls().boost,"Use pickup works alongside steering and boost")
	touch(6,"fire",false)
	check(not pad.controls().fire,"Releasing use ends the held input")
	check(pad.controls().brake==1. and pad.controls().throttle==0. and pad.controls().boost,"Brake cuts power while multiple fingers remain active")
	touch(3,"brake",false)
	check(pad.controls().throttle==1. and pad.controls().brake==0.,"Releasing brake restores selected throttle")
	pad.move_finger(1,pad.centers().flight)
	check(pad.fingers[1]=="steer" and pad.controls().strafe==-.5,"Crossing screen does not steal opposite stick")
	var cancel:=InputEventScreenTouch.new()
	cancel.index=2
	cancel.canceled=true
	pad._input(cancel)
	check(pad.controls().strafe==0. and pad.controls().trim==0.,"Canceled Android touch clears axes")
	touch(5,"reset")
	check(not pad.controls().reset,"Reset hidden and inactive on road")
	pad.reset_available=true
	touch(5,"reset")
	check(pad.controls().reset,"Recovery button is usable off track")
	pad.hide()
	check(pad.fingers.is_empty() and pad.controls().throttle==0.,"Pause/hiding clears all touch state")
	pad.show()
	touch(0,"throttle")
	var paused:=[false]
	pad.pause_requested.connect(func(): paused[0]=true)
	touch(1,"pause")
	check(paused[0] and pad.controls().throttle==0.,"Pause responds and clears throttle")
	pad.queue_free()
	await process_frame
	print("TOUCH_TESTS ",failures," failures")
	quit(1 if failures else 0)
