extends Control
signal pause_requested

# Finger ownership is fixed until release; dragging across another control
# never steals it. Both sticks, brake and boost can be used simultaneously.
var fingers:Dictionary={}
var sticks:Dictionary={"steer":Vector2.ZERO,"flight":Vector2.ZERO}
var throttle_on:=false
var reset_available:=false
var weapon_available:=false
var radius:=82.0
var gamepad_active:=false

func _ready()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(func():
		if not visible: clear_input())

func clear_input()->void:
	fingers.clear()
	sticks={"steer":Vector2.ZERO,"flight":Vector2.ZERO}
	throttle_on=false
	queue_redraw()

func centers()->Dictionary:
	return {"steer":Vector2(165,size.y-225),"flight":Vector2(size.x-165,size.y-225),
		"throttle":Vector2(365,size.y-105),"brake":Vector2(355,size.y-245),
		"fire":Vector2(size.x-365,size.y-105),"boost":Vector2(size.x-355,size.y-245),"reset":Vector2(size.x*.5,size.y-100),
		"left":Vector2(size.x*.5-70,size.y-230),"right":Vector2(size.x*.5+70,size.y-230),
		"pause":Vector2(size.x*.5,52)}

func _input(event:InputEvent)->void:
	if not visible: return
	if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value)>.25):
		if not gamepad_active: clear_input()
		gamepad_active=true
	if event is InputEventScreenTouch:
		if event.pressed: gamepad_active=false
		if not event.pressed or event.canceled:
			release_finger(event.index)
			return
		var positions:=centers()
		for id:String in positions:
			if id=="reset" and not reset_available: continue
			if id=="fire" and not weapon_available: continue
			var limit:=radius+20 if id in sticks else 54.
			if event.position.distance_to(positions[id])>limit: continue
			if fingers.values().has(id): return
			if id=="pause":
				clear_input()
				pause_requested.emit()
			elif id=="throttle": throttle_on=not throttle_on
			else:
				fingers[event.index]=id
				move_finger(event.index,event.position)
			get_viewport().set_input_as_handled()
			queue_redraw()
			return
	elif event is InputEventScreenDrag and fingers.has(event.index):
		move_finger(event.index,event.position)
		get_viewport().set_input_as_handled()

func move_finger(index:int,point:Vector2)->void:
	var id:String=fingers.get(index,"")
	if sticks.has(id):
		var offset:Vector2=(point-centers()[id])/radius
		sticks[id]=offset.limit_length(1.)
	queue_redraw()

func release_finger(index:int)->void:
	var id:String=fingers.get(index,"")
	if sticks.has(id): sticks[id]=Vector2.ZERO
	fingers.erase(index)
	queue_redraw()

func controls()->Dictionary:
	var held:=fingers.values()
	return {"steer":sticks.steer.x,"strafe":sticks.flight.x,"trim":-sticks.flight.y,
		"throttle":float(throttle_on and not held.has("brake")),"brake":float(held.has("brake")),
		"left":held.has("left"),"right":held.has("right"),
		"fire":weapon_available and held.has("fire"),"boost":held.has("boost"),"reset":reset_available and held.has("reset")}

func _process(_dt:float)->void:
	if visible: queue_redraw()

func _draw()->void:
	var positions:=centers()
	var font:=ThemeDB.fallback_font
	for id:String in positions:
		if gamepad_active and id!="pause": continue
		if id=="reset" and not reset_available: continue
		if id=="fire" and not weapon_available: continue
		var point:Vector2=positions[id]
		var is_stick:bool=id in sticks
		var active:bool=fingers.values().has(id) or (id=="throttle" and throttle_on)
		var r:float=radius if is_stick else 46.
		draw_circle(point,r,Color(.01,.025,.04,.32))
		draw_arc(point,r,0,TAU,48,Color(.5,.95,.85,.8) if active else Color(1,1,1,.3),2,true)
		if is_stick:
			draw_circle(point+sticks[id]*radius,23,Color(.65,1,.9,.55))
		var title:String={"left":"Bump L","right":"Bump R","steer":"Steer","flight":"Flight","throttle":"Power" if throttle_on else "Throttle","brake":"Brake","boost":"Boost","reset":"Reset","fire":"Use","pause":"Ⅱ"}[id]
		var width:=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x
		draw_string(font,point+Vector2(-width*.5,r+26 if is_stick else 7),title,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(1,1,1,.8))
