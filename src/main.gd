extends Node
const Race = preload("res://src/race.gd")
const World = preload("res://src/world.gd")
const Hud = preload("res://src/hud.gd")
const Bridge = preload("res://src/bridge.gd")
const KEYS = [
	[KEY_A,KEY_D,KEY_W,KEY_S,KEY_SPACE,KEY_Q,KEY_E],
	[KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_CTRL,KEY_COMMA,KEY_PERIOD],
	[KEY_J,KEY_L,KEY_I,KEY_K,KEY_U,KEY_Y,KEY_O],
	[KEY_F,KEY_H,KEY_T,KEY_G,KEY_R,KEY_V,KEY_B],
]
var bridge: Node
var race: RefCounted
var world: Node3D
var views: Array[Dictionary] = []
var ui: Control
var menu: Control
var roster: Array = []
var running := false
var in_menu := true
var human_count := 1
const MAX_SEED := 99999
var next_seed := 0
var selected_seed := 1
var seed_input:LineEdit
var laps := 3
var quality := 1.0
var results_clock := 0.0
var back_release := 0.0
var activity_clock := 0.0
var engine_sound: AudioStreamPlayer
var demo := false
var capture_path := ""
var capture_frame := 180
var frame_number := 0
var frame_times: Array[float] = []
var last_frame_usec := 0
var headless := false
var probe_clock := 0.0
var preview_u := 0.0
var show_menu_controls := false
var sound_enabled := false
var menu_sticks:Dictionary={}
var menu_direction:=Vector2i.ZERO
var menu_repeat:=0.0

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	Engine.max_fps = 120
	Input.joy_connection_changed.connect(func(device:int,connected:bool):
		if not connected: menu_sticks.erase(device))
	bridge = Bridge.new()
	bridge.prepared.connect(prepare)
	bridge.started.connect(start_managed)
	bridge.paused.connect(pause_managed)
	bridge.resumed.connect(start_managed)
	bridge.disposed.connect(dispose_managed)
	bridge.roster_changed.connect(update_profiles)
	bridge.daemon_disconnected.connect(func(): get_tree().quit())
	bridge.setting_changed.connect(setting_changed)
	add_child(bridge)
	bridge.declare_settings([
		{"key":"laps","label":"Laps (next race)","kind":"number","default":3,"min":1,"max":5},
		{"key":"quality","label":"Graphics","kind":"choice","default":"high","options":["performance","balanced","high"]}])
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(ui)
	get_viewport().size_changed.connect(layout_views)
	setup_audio()
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg == "--demo": demo = true
		elif arg.begins_with("--players="): human_count = clampi(int(arg.get_slice("=",1)),1,4)
		elif arg.begins_with("--seed="): next_seed = int(arg.get_slice("=",1))
		elif arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-frame="): capture_frame = int(arg.get_slice("=",1))
		elif arg.begins_with("--preview-u="): preview_u = clampf(float(arg.get_slice("=",1)),0,.99)
	if bridge.launched_by_daemon:
		in_menu = false
		quiet_window()
	else:
		if demo:
			start_local()
			if preview_u>0:
				for i in range(race.track.nodes.size()):
					if race.track.nodes[i].u>=preview_u:
						for p in race.racers:
							p.distance=i*race.track.step-p.slot*9
							p.speed=240.0
						race.countdown=0
						race.clock=20
						break
		else:
			roster = local_roster(1, true)
			new_race()
			make_menu()

func local_roster(count: int, bots_only: bool = false) -> Array:
	var out: Array = []
	var pads := Input.get_connected_joypads()
	for i in range(maxi(count,6)):
		out.append({"slot":i,"id":str(i),"name":["NOVA","FLUX","COMET","VECTOR","ECHO","PULSE"][i],
			"bot":bots_only or i>=count,"device":int(pads[i]) if i<pads.size() else -1,
			"view":i<count,"color":World.PALETTE[i].to_html()})
	return out

func start_selected() -> void:
	finish_seed_edit()
	next_seed=selected_seed
	start_local()

func seed_text_changed(value:String)->void:
	var digits:=""
	for character in value:
		if character>="0" and character<="9": digits+=character
	if digits!=value:
		var caret:=seed_input.caret_column
		seed_input.text=digits
		seed_input.caret_column=mini(caret,digits.length())
	if int(digits)>0: selected_seed=clampi(int(digits),1,MAX_SEED)

func finish_seed_edit()->void:
	if is_instance_valid(seed_input): seed_input.text="%05d"%selected_seed

func randomize_menu_seed()->void:
	# Pick a different five-digit code, even on repeated presses.
	selected_seed=(selected_seed+randi_range(1,MAX_SEED-1)-1)%MAX_SEED+1
	finish_seed_edit()

func start_local() -> void:
	if is_instance_valid(menu): menu.queue_free()
	roster = local_roster(human_count,demo)
	in_menu = false
	running = true
	new_race()

func new_race() -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	for view in views:
		ui.remove_child(view.holder)
		view.holder.queue_free()
	views.clear()
	if next_seed == 0: next_seed = randi_range(1,MAX_SEED)
	next_seed=clampi(next_seed,1,MAX_SEED)
	race = Race.new(roster,next_seed,laps)
	next_seed = next_seed%MAX_SEED+1
	results_clock = 0
	world = World.new()
	add_child(world)
	world.build(race)
	var indices: Array[int] = []
	for i in range(race.racers.size()):
		if race.racers[i].get("view",not race.racers[i].bot): indices.append(i)
	if indices.is_empty() and not race.racers.is_empty(): indices.append(0)
	for index in indices.slice(0,4):
		var holder := Control.new()
		ui.add_child(holder)
		var viewport := SubViewport.new()
		viewport.world_3d = get_viewport().world_3d
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_2X if quality>=.8 else Viewport.MSAA_DISABLED
		holder.add_child(viewport)
		var image := TextureRect.new()
		image.texture = viewport.get_texture()
		var blur:=ShaderMaterial.new()
		blur.shader=load("res://src/speed_blur.gdshader")
		image.material=blur
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(image)
		var camera := Camera3D.new()
		camera.far = 5000
		camera.near = .5
		viewport.add_child(camera)
		camera.current = true
		var hud := Hud.new()
		hud.race = race
		hud.player_index = index
		hud.show_map = indices.size() == 1
		hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(hud)
		views.append({"holder":holder,"viewport":viewport,"camera":camera,"hud":hud,"index":index,"blur":blur})
		world.update_camera(camera,index,0,true)
	layout_views()

func layout_views() -> void:
	var dimensions := get_viewport().get_visible_rect().size
	var count := views.size()
	if is_instance_valid(world): world.set_quality(quality,count)
	for i in range(count):
		var columns := 2 if count>2 else 1
		var rows := 2 if count>1 else 1
		var cell := dimensions/Vector2(columns,rows)
		views[i].holder.position = Vector2(i%columns,i/columns)*cell
		views[i].holder.size = cell-Vector2.ONE*2
		# UI uses logical coordinates; 3D must use actual output pixels in fullscreen.
		var output_pixels:=Vector2(get_window().size)
		views[i].viewport.size = Vector2i((cell/dimensions)*output_pixels*quality)
		views[i].viewport.msaa_3d = Viewport.MSAA_2X if quality>=.8 else Viewport.MSAA_DISABLED
		views[i].viewport.positional_shadow_atlas_size=(2048 if count==1 and quality>=1. else 1024) if quality>=.8 else 0

func _physics_process(dt: float) -> void:
	if race == null: return
	if not running and not in_menu: return
	if race.over:
		results_clock += dt
		if results_clock>=8: new_race()
		return
	var inputs: Array = []
	for p in race.racers:
		inputs.append(race.bot(p) if p.bot or in_menu or p.get("sleeping",false) else controls(p))
	race.step(dt,inputs)
	if race.over and bridge.launched_by_daemon: bridge.notify_finished(bridge.session)

func controls(p: Dictionary) -> Dictionary:
	if bridge.launched_by_daemon: return bridge.controls(p.get("controller",""))
	var k: Array = KEYS[int(p.slot)%4]
	var c := {"steer":float(Input.is_physical_key_pressed(k[1]))-float(Input.is_physical_key_pressed(k[0])),
		"throttle":float(Input.is_physical_key_pressed(k[2])),"brake":float(Input.is_physical_key_pressed(k[3])),
		"trim":0.0,"strafe":0.0,"boost":Input.is_physical_key_pressed(k[4]),"left":Input.is_physical_key_pressed(k[5]),"right":Input.is_physical_key_pressed(k[6])}
	var device: int = p.get("device",-1)
	if device>=0 and Input.get_connected_joypads().has(device):
		var axis := Input.get_joy_axis(device,JOY_AXIS_LEFT_X)
		if absf(axis)>.15: c.steer=signf(axis)*(absf(axis)-.15)/.85
		if Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_LEFT): c.steer=-1.0
		if Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_RIGHT): c.steer=1.0
		c.throttle=maxf(c.throttle,maxf(Input.get_joy_axis(device,JOY_AXIS_TRIGGER_RIGHT),float(Input.is_joy_button_pressed(device,JOY_BUTTON_A))))
		var right_x:=Input.get_joy_axis(device,JOY_AXIS_RIGHT_X)
		var right_y:=Input.get_joy_axis(device,JOY_AXIS_RIGHT_Y)
		c.strafe=signf(right_x)*maxf(0,(absf(right_x)-.15)/.85)
		c.trim=-signf(right_y)*maxf(0,(absf(right_y)-.15)/.85)
		c.brake=maxf(c.brake,maxf(float(Input.is_joy_button_pressed(device,JOY_BUTTON_X)),clampf((Input.get_joy_axis(device,JOY_AXIS_TRIGGER_LEFT)-.06)/.94,0,1)))
		c.boost=c.boost or Input.is_joy_button_pressed(device,JOY_BUTTON_B)
		c.left=c.left or Input.is_joy_button_pressed(device,JOY_BUTTON_LEFT_SHOULDER)
		c.right=c.right or Input.is_joy_button_pressed(device,JOY_BUTTON_RIGHT_SHOULDER)
	return c

func _process(dt: float) -> void:
	navigate_menu(dt)
	process_back(dt)
	probe_clock+=dt
	if probe_clock>=.05:
		probe_clock=0
		write_probe()
	if race == null: return
	if running or in_menu:
		world.update_ships()
		for view in views: world.update_camera(view.camera,view.index,dt)
	for view in views:
		var blur_amount:=smoothstep(110.,340.,float(race.racers[view.index].speed))*.035
		view.blur.set_shader_parameter("amount",blur_amount if quality>=.8 and running and race.countdown<=0 else 0.)
		view.hud.visible=not in_menu
		view.hud.queue_redraw()
	update_audio()
	activity_clock += dt
	if running and bridge.launched_by_daemon and activity_clock>=1:
		activity_clock=0
		for p in race.racers:
			if p.bot: continue
			var token: String=p.get("controller","")
			var input: Dictionary=bridge.controls(token)
			if absf(input.steer)>.25 or input.throttle>.25 or input.brake or input.boost or input.left or input.right:
				bridge._send({"type":"controller_input","session":bridge.session,"controller":token})
	if not capture_path.is_empty():
		frame_number+=1
		var now := Time.get_ticks_usec()
		if frame_number>30: frame_times.append((now-last_frame_usec)/1000.0)
		last_frame_usec=now
		if frame_number==capture_frame:
			capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_path)
	frame_times.sort()
	var sum:=0.0
	for value in frame_times: sum+=value
	print("ION_RENDER ",JSON.stringify({"views":views.size(),"frames":frame_times.size(),"mean_ms":sum/maxi(1,frame_times.size()),
		"p95_ms":frame_times[int(frame_times.size()*.95)] if not frame_times.is_empty() else 0,
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"capture":capture_path}))
	get_tree().quit()

func process_back(dt:float)->void:
	var held:=Input.is_physical_key_pressed(KEY_ESCAPE)
	if bridge.launched_by_daemon:
		for token in bridge.frames:
			held=held or Bridge.pressed(bridge.frame(token),6)
	else:
		for device in Input.get_connected_joypads(): held=held or Input.is_joy_button_pressed(device,JOY_BUTTON_BACK)
	if not held:
		back_release=minf(1,back_release+dt)
	elif back_release>=1:
		back_release=0
		if bridge.launched_by_daemon:
			if running: bridge.request_overlay()
		elif not in_menu:
			running=false
			in_menu=true
			make_menu()

func _input(event:InputEvent)->void:
	if not in_menu or bridge.launched_by_daemon: return
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
		var stick:Vector2=menu_sticks.get(event.device,Vector2.ZERO)
		if event.axis==JOY_AXIS_LEFT_X: stick.x=event.axis_value
		else: stick.y=event.axis_value
		menu_sticks[event.device]=stick
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_START,JOY_BUTTON_A]:
		get_viewport().set_input_as_handled()
		if not event.pressed: return
		if event.button_index==JOY_BUTTON_START:
			start_selected()
		else:
			var focused:=get_viewport().gui_get_focus_owner()
			if focused is Button and menu.is_ancestor_of(focused): focused.pressed.emit()
			elif focused is LineEdit:
				focused.edit()
				focused.select_all()
			else: start_selected()

func navigate_menu(dt:float)->void:
	if not in_menu or not is_instance_valid(menu): return
	var stick:=Vector2.ZERO
	for value:Vector2 in menu_sticks.values():
		if value.length_squared()>stick.length_squared(): stick=value
	var direction:=Vector2i.ZERO
	if maxf(absf(stick.x),absf(stick.y))>.55:
		direction=Vector2i(int(signf(stick.x)),0) if absf(stick.x)>absf(stick.y) else Vector2i(0,int(signf(stick.y)))
	menu_repeat-=dt
	if direction==Vector2i.ZERO:
		menu_direction=direction
		menu_repeat=0
		return
	if direction==menu_direction and menu_repeat>0: return
	menu_repeat=.32 if direction!=menu_direction else .14
	menu_direction=direction
	var focused:=get_viewport().gui_get_focus_owner()
	if focused==null or not menu.is_ancestor_of(focused): return
	var side:=SIDE_LEFT if direction.x<0 else (SIDE_RIGHT if direction.x>0 else (SIDE_TOP if direction.y<0 else SIDE_BOTTOM))
	var path:=focused.get_focus_neighbor(side)
	if not path.is_empty():
		var next:=focused.get_node_or_null(path) as Control
		if next: next.grab_focus()

func _unhandled_input(event:InputEvent)->void:
	if bridge.launched_by_daemon: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ENTER and in_menu: start_selected()
		elif event.keycode==KEY_F2 and in_menu:
			human_count=human_count%4+1
			make_menu()
		elif event.keycode==KEY_F5 and not in_menu: new_race()

func menu_style(fill:Color,border:Color=Color.TRANSPARENT)->StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=fill
	style.border_color=border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left=18
	style.content_margin_right=18
	return style

func style_button(button:Button,primary:bool=false,selected:bool=false)->void:
	var mint:=Color("7de9d6")
	button.add_theme_font_size_override("font_size",18)
	button.add_theme_color_override("font_color",Color("102b30") if primary else (mint if selected else Color("d1dce4")))
	button.add_theme_color_override("font_hover_color",Color("102b30") if primary else Color.WHITE)
	button.add_theme_color_override("font_pressed_color",Color("102b30") if primary else mint)
	button.add_theme_color_override("font_focus_color",Color("102b30") if primary else Color.WHITE)
	button.add_theme_stylebox_override("normal",menu_style(mint if primary else Color(1,1,1,.045),mint if selected else Color(1,1,1,.12)))
	button.add_theme_stylebox_override("hover",menu_style(mint.lightened(.2) if primary else Color(1,1,1,.12)))
	button.add_theme_stylebox_override("pressed",menu_style(mint.darkened(.15) if primary else Color(.2,.7,.6,.2)))
	button.add_theme_stylebox_override("focus",menu_style(Color.TRANSPARENT,Color(1,1,1,.6)))

func make_menu()->void:
	var focus_id:="race"
	if not is_instance_valid(menu): selected_seed=race.track.seed_value
	if is_instance_valid(menu):
		var focused:=get_viewport().gui_get_focus_owner()
		if focused and menu.is_ancestor_of(focused): focus_id=str(focused.get_meta("menu_id","race"))
		ui.remove_child(menu)
		menu.queue_free()
	menu=Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var shade:=ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var fade:=ShaderMaterial.new()
	fade.shader=load("res://src/menu_backdrop.gdshader")
	shade.material=fade
	menu.add_child(shade)
	var content:=VBoxContainer.new()
	content.position=Vector2(110,95)
	content.size=Vector2(430,630)
	content.add_theme_constant_override("separation",16)
	menu.add_child(content)
	menu_label(content,"G A M E N I G H T",14,Color("7de9d6"))
	menu_label(content,"ION RUSH",68,Color("edf7ff"))
	menu_label(content,"Find your line.",21,Color("aebfca"))
	var spacer:=Control.new()
	spacer.custom_minimum_size.y=10
	content.add_child(spacer)
	menu_label(content,"PLAYERS",12,Color("91a8b7"))
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	content.add_child(row)
	var players:Array[Button]=[]
	for i in range(1,5):
		var button:=Button.new()
		button.set_meta("menu_id","player%d"%i)
		players.append(button)
		button.text=str(i)
		button.custom_minimum_size=Vector2(100,46)
		style_button(button,false,i==human_count)
		button.pressed.connect(func(): human_count=i;make_menu())
		row.add_child(button)
	menu_label(content,"TRACK SEED",12,Color("91a8b7"))
	var seed_row:=HBoxContainer.new()
	seed_row.add_theme_constant_override("separation",10)
	content.add_child(seed_row)
	seed_input=LineEdit.new()
	seed_input.set_meta("menu_id","seed")
	seed_input.text="%05d"%selected_seed
	seed_input.max_length=5
	seed_input.select_all_on_focus=true
	seed_input.custom_minimum_size=Vector2(280,46)
	seed_input.add_theme_font_size_override("font_size",24)
	seed_input.add_theme_color_override("font_color",Color("edf7ff"))
	seed_input.add_theme_stylebox_override("normal",menu_style(Color(1,1,1,.045),Color(1,1,1,.12)))
	seed_input.add_theme_stylebox_override("focus",menu_style(Color.TRANSPARENT,Color("7de9d6")))
	seed_input.text_changed.connect(seed_text_changed)
	seed_input.focus_exited.connect(finish_seed_edit)
	seed_input.text_submitted.connect(func(_value:String): start_selected())
	seed_row.add_child(seed_input)
	var random_button:=Button.new()
	random_button.set_meta("menu_id","random")
	random_button.text="Random"
	random_button.custom_minimum_size=Vector2(140,46)
	style_button(random_button)
	random_button.pressed.connect(randomize_menu_seed)
	seed_row.add_child(random_button)
	var start:=Button.new()
	start.set_meta("menu_id","race")
	start.text="Race    \u2192"
	start.alignment=HORIZONTAL_ALIGNMENT_LEFT
	start.custom_minimum_size=Vector2(430,58)
	style_button(start,true)
	start.pressed.connect(start_selected)
	content.add_child(start)
	var links:=HBoxContainer.new()
	links.add_theme_constant_override("separation",14)
	content.add_child(links)
	var help:=Button.new()
	help.set_meta("menu_id","controls")
	help.text="Hide controls" if show_menu_controls else "Controls"
	help.flat=true
	help.add_theme_font_size_override("font_size",16)
	help.add_theme_color_override("font_color",Color("aebfca"))
	help.pressed.connect(func(): show_menu_controls=not show_menu_controls;make_menu())
	links.add_child(help)
	var quality_button:=Button.new()
	quality_button.set_meta("menu_id","graphics")
	quality_button.flat=true
	quality_button.text="Graphics \u00b7 %s"%({.6:"Performance",.8:"Balanced",1.0:"High"}.get(quality,"Balanced"))
	quality_button.add_theme_font_size_override("font_size",16)
	quality_button.add_theme_color_override("font_color",Color("aebfca"))
	quality_button.pressed.connect(func(): quality=.8 if quality==.6 else (1.0 if quality==.8 else .6);layout_views();make_menu())
	links.add_child(quality_button)
	if show_menu_controls:
		menu_label(content,"A / RT   Accelerate     B   Boost     LT   Brake / slide\nRoad: right stick strafes / trims grip; pull back to lift off\nFlight: left stick rolls; right stick pitches / yaws; LT air brake",16,Color("bacbd5"))
		menu_label(content,"P1  WASD / Space / Q E     P2  Arrows / Ctrl / , .\nP3  IJKL / U / Y O               P4  TFGH / R / V B",14,Color("91a8b7"))
		menu_label(content,"Back: nose up / takeoff. Forward: nose down.\nIn flight, bank and align with the road to land.",14,Color("91a8b7"))
	for i in range(players.size()):
		players[i].focus_neighbor_left=players[posmod(i-1,4)].get_path()
		players[i].focus_neighbor_right=players[(i+1)%4].get_path()
		players[i].focus_neighbor_bottom=seed_input.get_path()
		players[i].focus_neighbor_top=help.get_path()
	seed_input.focus_neighbor_left=random_button.get_path()
	seed_input.focus_neighbor_right=random_button.get_path()
	random_button.focus_neighbor_left=seed_input.get_path()
	random_button.focus_neighbor_right=seed_input.get_path()
	for control in [seed_input,random_button]:
		control.focus_neighbor_top=players[human_count-1].get_path()
		control.focus_neighbor_bottom=start.get_path()
	start.focus_neighbor_top=seed_input.get_path()
	start.focus_neighbor_bottom=help.get_path()
	start.focus_neighbor_left=start.get_path()
	start.focus_neighbor_right=start.get_path()
	help.focus_neighbor_right=quality_button.get_path()
	help.focus_neighbor_left=quality_button.get_path()
	quality_button.focus_neighbor_right=help.get_path()
	quality_button.focus_neighbor_left=help.get_path()
	for button in [help,quality_button]:
		button.focus_neighbor_top=start.get_path()
		button.focus_neighbor_bottom=players[human_count-1].get_path()
		button.add_theme_stylebox_override("focus",menu_style(Color.TRANSPARENT,Color("7de9d6")))
	menu_label(content,"Left stick  Navigate     A  Select     Start  Race",13,Color("91a8b7"))
	start.grab_focus()
	for button in players+[seed_input,random_button,start,help,quality_button]:
		if button.get_meta("menu_id")==focus_id: button.grab_focus()

func menu_label(parent:Node,value:String,size_value:int,color:Color=Color("d5e1ec"))->void:
	var label:=Label.new()
	label.text=value
	label.add_theme_font_size_override("font_size",size_value)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)

func managed_roster(seats:Array,players:Array)->Array:
	var out:Array=[]
	for seat in seats:
		var occupant:Dictionary=seat.get("occupant",{})
		if occupant.get("kind","empty")=="empty": continue
		var profile:Dictionary={}
		for player in players:
			if player.get("id","")==occupant.get("player_id","!"): profile=player.duplicate(true)
		profile.merge({"slot":int(seat.get("index",0)),"id":occupant.get("player_id",""),
			"bot":occupant.get("kind","")=="ai","controller":str(seat.get("controller","")),
			"view":occupant.get("kind","")!="ai"},true)
		if not profile.has("name"): profile.name="CPU %d"%(out.size()+1)
		out.append(profile)
	return out

func prepare(session:String,seats:Array,players:Array)->void:
	running=false
	quiet_window()
	roster=managed_roster(seats,players)
	new_race()
	# Draw at real display dimensions before Ready. Park off-screen while warming.
	if not headless:
		get_window().mode=Window.MODE_WINDOWED
		for warmup in range(60): await RenderingServer.frame_post_draw
	if bridge.session!=session: return
	quiet_window()
	bridge.ready_for_session(session)
	Engine.max_fps=30

func start_managed(_session:String)->void:
	back_release=0
	running=true
	Engine.max_fps=120
	AudioServer.set_bus_mute(0,not sound_enabled)
	if not headless:
		var window:=get_window()
		window.mode=Window.MODE_WINDOWED
		window.position=DisplayServer.screen_get_position()
		window.grab_focus()

func quiet_window()->void:
	AudioServer.set_bus_mute(0,true)
	if not headless:
		var window:=get_window()
		window.borderless=true
		window.size=DisplayServer.screen_get_size()+Vector2i(0,1 if OS.get_name()=="Windows" else 0)
		window.position=Vector2i(-20000,-20000)
		# Godot cannot hide its main Window. Minimize and park it off-screen.
		window.mode=Window.MODE_MINIMIZED

func pause_managed(_session:String)->void:
	running=false
	back_release=0
	quiet_window()
	Engine.max_fps=30

func dispose_managed(_session:String)->void:
	pause_managed(_session)
	race=null
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	for view in views:
		ui.remove_child(view.holder)
		view.holder.queue_free()
	views.clear()

func update_profiles(seats:Array,players:Array,presence:Array)->void:
	var incoming:=managed_roster(seats,players)
	roster=incoming
	if race==null: return
	for p in race.racers:
		var matched:=false
		for identity in incoming:
			if (not str(p.get("id","")).is_empty() and p.id==identity.id) or (p.bot and identity.bot and p.slot==identity.slot):
				matched=true
				for field in ["name","color","skin_color","avatar","controller","slot"]:
					p[field]=identity.get(field,"" if field!="slot" else 0)
		p.sleeping=not matched
		for status in presence:
			if status.get("player_id","")==p.get("id",""): p.sleeping=status.get("state","")=="sleeping"

func setting_changed(key:String,value:Variant)->void:
	if key=="laps": laps=clampi(int(value),1,5)
	elif key=="quality":
		quality={"performance":.6,"balanced":.8,"high":1.0}.get(str(value),1.0)
		layout_views()

func setup_audio()->void:
	AudioServer.set_bus_mute(0,not sound_enabled)
	var data:=PackedByteArray()
	for i in range(22050):
		var t:=float(i)/22050
		var value:=int((sin(TAU*55*t)*.45+sin(TAU*110*t)*.2+sin(TAU*165*t)*.1)*12000)
		data.append(value&255)
		data.append((value>>8)&255)
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=22050
	stream.data=data
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_end=22050
	engine_sound=AudioStreamPlayer.new()
	engine_sound.stream=stream
	engine_sound.volume_db=-80
	add_child(engine_sound)
	engine_sound.play()

func update_audio()->void:
	if race==null or not running or race.over or race.countdown>0:
		engine_sound.volume_db=-80
		return
	var speed:=0.0
	for view in views: speed=maxf(speed,race.racers[view.index].speed)
	engine_sound.pitch_scale=.65+speed/130
	engine_sound.volume_db=-28+speed/80

func write_probe()->void:
	var path:=OS.get_environment("ION_PROBE_PATH")
	if path.is_empty(): return
	var snapshot:Array=[]
	if race:
		for p in race.racers:
			var copy:Dictionary=p.duplicate()
			for key in ["time","best_lap"]:
				if not is_finite(copy[key]): copy[key]=null
			snapshot.append(copy)
	var state:Dictionary={"phase":bridge.phase,"running":running,
		"visible":get_window().mode!=Window.MODE_MINIMIZED and get_window().position.x> -10000,
		"sound_enabled":sound_enabled,"muted":AudioServer.is_bus_mute(0),"clock":race.clock if race else -1,"countdown":race.countdown if race else -1,"vfx_clock":race.vfx_clock if race else -1,
		"racers":snapshot,"views":views.size(),"session":bridge.session,
		"city_time":world.scenery.animation_time if race and is_instance_valid(world) else 0.0,
		"traffic_position":str(world.scenery.traffic.get_instance_transform(0).origin) if race and is_instance_valid(world) and world.scenery.traffic.instance_count>0 else "",
		"tunnel_time":world.tunnel_material.get_shader_parameter("race_time") if race and is_instance_valid(world) else 0.0}
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(state))

func _exit_tree()->void:
	if is_instance_valid(engine_sound):
		engine_sound.stop()
		engine_sound.stream=null
