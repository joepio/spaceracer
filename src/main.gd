extends Node
const Race = preload("res://src/race.gd")
const World = preload("res://src/world.gd")
const Hud = preload("res://src/hud.gd")
const Visor = preload("res://src/visor.gd")
const SpeedEffects = preload("res://src/speed_effects.gd")
const Bridge = preload("res://src/bridge.gd")
const KEYS = [
	[KEY_A,KEY_D,KEY_W,KEY_S,KEY_SPACE,KEY_Q,KEY_E],
	[KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_CTRL,KEY_COMMA,KEY_PERIOD],
	[KEY_J,KEY_L,KEY_I,KEY_K,KEY_U,KEY_Y,KEY_O],
	[KEY_F,KEY_H,KEY_T,KEY_G,KEY_R,KEY_V,KEY_B],
]
var cheats:=preload("res://src/dev_cheats.gd").new()
var dev_label:Label
var bridge: Node
var race: RefCounted
var world: Node3D
var views: Array[Dictionary] = []
var ui: Control
var menu: Control
var roster: Array = []
var running := false
var in_menu := true
var local_paused := false
var human_count := 1
const MAX_SEED := 99999
var next_seed := 0
var selected_seed := 1
var seed_input:LineEdit
var track_character:Label
var laps := 3
var difficulty := "normal"
var biome := "city"
var quality := 1.0
var bounce_lighting:=false
var results_clock := 0.0
var back_release := 0.0
var activity_clock := 0.0
var engine_sound: AudioStreamPlayer
var missile_sound:Node
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
var menu_rows:Array[Control]=[]
var menu_holds:Dictionary={}
var menu_hold_bar:ProgressBar
var menu_hold_hint:Label
const MENU_HOLD_SECONDS:=1.
var pause_settings:Dictionary={}
var touch_controls:Control
var mobile_mode:=false
var preview_refresh:=0.0

func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	mobile_mode=OS.has_feature("android") or "--touch" in OS.get_cmdline_user_args()
	quality=.6 if mobile_mode else quality
	Engine.max_fps = 60 if mobile_mode else 120
	Input.joy_connection_changed.connect(func(device:int,connected:bool):
		if not connected:
			menu_sticks.erase(device)
			for key:Vector2i in menu_holds.keys():
				if key.x==device: menu_holds.erase(key)
		assign_local_controllers())
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
		{"key":"difficulty","label":"Track difficulty (next race)","kind":"choice","default":"normal","options":["easy","normal","hard"]},
		{"key":"biome","label":"World (next race)","kind":"choice","default":"city","options":Race.Track.BIOMES},
		{"key":"seed","label":"Track seed (0 = random, next race)","kind":"number","default":0,"min":0,"max":99999},
		{"key":"quality","label":"Graphics","kind":"choice","default":"high","options":["performance","balanced","high"]}])
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(ui)
	dev_label=Label.new()
	dev_label.text=cheats.LEGEND
	dev_label.position=Vector2(18,48)
	dev_label.add_theme_font_size_override("font_size",14)
	dev_label.add_theme_color_override("font_color",Color("ffd16b"))
	dev_label.add_theme_constant_override("outline_size",5)
	dev_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dev_label.visible=false
	canvas.add_child(dev_label)
	if mobile_mode:
		touch_controls=load("res://src/touch_controls.gd").new()
		touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		canvas.add_child(touch_controls)
		touch_controls.pause_requested.connect(pause_local)
	get_tree().auto_accept_quit=false
	get_viewport().size_changed.connect(layout_views)
	setup_audio()
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg == "--demo": demo = true
		elif arg=="--dev": cheats.enabled=true;dev_label.visible=true
		elif arg=="--sdfgi": bounce_lighting=true
		elif arg=="--direct-lighting": bounce_lighting=false
		elif arg.begins_with("--players="): human_count = clampi(int(arg.get_slice("=",1)),1,4)
		elif arg.begins_with("--seed="): next_seed = int(arg.get_slice("=",1))
		elif arg.begins_with("--difficulty=") and arg.get_slice("=",1) in Race.Track.DIFFICULTIES: difficulty=arg.get_slice("=",1)
		elif arg.begins_with("--biome=") and arg.get_slice("=",1) in Race.Track.BIOMES: biome=arg.get_slice("=",1)
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
	if local_paused and not menu_race_changed():
		resume_local()
		return
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
	preview_refresh=.4
	refresh_menu_values()

func finish_seed_edit()->void:
	if is_instance_valid(seed_input): seed_input.text="%05d"%selected_seed

func randomize_menu_seed()->void:
	# Pick a different five-digit code, even on repeated presses.
	selected_seed=(selected_seed+randi_range(1,MAX_SEED-1)-1)%MAX_SEED+1
	preview_refresh=.4
	finish_seed_edit()
	refresh_menu_values()

func start_random_race()->void:
	randomize_scenery()
	randomize_menu_seed()
	next_seed=selected_seed
	start_local()

func start_local() -> void:
	preview_refresh=0.
	menu_sticks.clear();menu_holds.clear();menu_direction=Vector2i.ZERO;menu_repeat=0.
	if is_instance_valid(touch_controls): touch_controls.clear_input()
	local_paused=false
	if is_instance_valid(menu): menu.queue_free()
	roster = local_roster(human_count,demo)
	in_menu = false
	running = true
	new_race()

func randomize_scenery()->void:
	# Independent rolls allow repeats, while giving all three settings equal odds.
	biome=Race.Track.BIOMES.pick_random()

func new_race(random_scenery:bool=false) -> void:
	if random_scenery: randomize_scenery()
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	for view in views:
		ui.remove_child(view.holder)
		view.holder.queue_free()
	views.clear()
	if next_seed == 0: next_seed = randi_range(1,MAX_SEED)
	next_seed=clampi(next_seed,1,MAX_SEED)
	race = Race.new(roster,next_seed,laps,difficulty,biome,randi_range(1,10000000))
	next_seed = next_seed%MAX_SEED+1
	results_clock = 0
	world = World.new()
	world.bounce_lighting=bounce_lighting
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
		configure_viewport_aa(viewport,quality)
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
		var speed_effects:=SpeedEffects.new()
		speed_effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(speed_effects)
		var camera := Camera3D.new()
		camera.far = 5000
		camera.near = .5
		viewport.add_child(camera)
		camera.current = true
		var hud := Hud.new()
		hud.camera=camera
		hud.race = race
		hud.player_index = index
		hud.show_map = indices.size() == 1
		hud.split_screen = indices.size() > 1
		hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		var visor:=Visor.new()
		visor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(visor)
		visor.setup(hud)
		views.append({"holder":holder,"viewport":viewport,"camera":camera,"hud":hud,"visor":visor,"index":index,"blur":blur,"speed_effects":speed_effects})
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
		var mobile_width:=1280. if quality<.8 else (1600. if quality<1. else 1920.)
		var render_scale:=minf(1.,mobile_width/output_pixels.x) if mobile_mode else quality
		views[i].viewport.size = Vector2i((cell/dimensions)*output_pixels*render_scale)
		# Instruments retain output resolution even when 3D uses Performance scaling.
		views[i].visor.set_resolution(Vector2i((cell/dimensions)*output_pixels))
		configure_viewport_aa(views[i].viewport,quality)
		views[i].viewport.positional_shadow_atlas_size=(2048 if count==1 and quality>=1. else 1024) if quality>=.8 else 0
		views[i].viewport.render_target_update_mode=SubViewport.UPDATE_ONCE if local_paused else SubViewport.UPDATE_ALWAYS
	if bridge.launched_by_daemon and bridge.phase in ["ready","paused"]: managed_rendering(false)

func _physics_process(dt: float) -> void:
	if local_paused: return
	if race == null: return
	if not running and not in_menu: return
	if race.over:
		race.step(dt,[])
		results_clock += dt
		if results_clock>=8: new_race(true)
		return
	var inputs: Array = []
	for p in race.racers:
		inputs.append(race.bot(p) if p.bot or in_menu or p.get("sleeping",false) else controls(p))
	for view in views:
		if race.racers[view.index].weapon=="railgun" and not race.racers[view.index].bot:
			inputs[view.index]["rail_view"]=race.Weapons.Railgun.view_context(race,view.index,view.camera)
	race.step(dt,inputs)
	if race.over and bridge.launched_by_daemon: bridge.notify_finished(bridge.session)

func driving_key(key:int)->bool:
	return Input.is_physical_key_pressed(key) and not (cheats.enabled and cheats.KEYS.has(key))

func controls(p: Dictionary) -> Dictionary:
	if bridge.launched_by_daemon: return bridge.controls(p.get("controller",""))
	var k: Array = KEYS[int(p.slot)%4]
	var c := {"steer":float(driving_key(k[1]))-float(driving_key(k[0])),
		"throttle":float(driving_key(k[2])),"brake":float(driving_key(k[3])),
		"fire":driving_key([KEY_X,KEY_SLASH,KEY_P,KEY_C][int(p.slot)%4]),"trim":0.0,"strafe":0.0,"boost":driving_key(k[4]),"left":driving_key(k[5]),"right":driving_key(k[6]),"reset":Input.is_physical_key_pressed(KEY_1+int(p.slot)%4)}
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
		c.trim=Bridge.pitch_axis(Input.get_joy_axis(device,JOY_AXIS_LEFT_Y),right_y)
		c.brake=maxf(c.brake,clampf((Input.get_joy_axis(device,JOY_AXIS_TRIGGER_LEFT)-.06)/.94,0,1))
		c.fire=c.fire or Input.is_joy_button_pressed(device,JOY_BUTTON_X)
		c.boost=c.boost or Input.is_joy_button_pressed(device,JOY_BUTTON_B)
		c.reset=c.reset or Input.is_joy_button_pressed(device,JOY_BUTTON_Y)
		c.left=c.left or Input.is_joy_button_pressed(device,JOY_BUTTON_LEFT_SHOULDER)
		c.right=c.right or Input.is_joy_button_pressed(device,JOY_BUTTON_RIGHT_SHOULDER)
	if int(p.slot)==0 and is_instance_valid(touch_controls) and touch_controls.visible:
		var touch:Dictionary=touch_controls.controls()
		for axis in ["steer","strafe","trim"]:
			if absf(touch[axis])>absf(c[axis]): c[axis]=touch[axis]
		for axis in ["throttle","brake"]: c[axis]=maxf(c[axis],touch[axis])
		c.left=c.left or touch.left
		c.right=c.right or touch.right
		c.fire=c.fire or touch.fire
		c.boost=c.boost or touch.boost
		c.reset=c.reset or touch.reset
	return c

func _process(dt: float) -> void:
	if in_menu and not local_paused and preview_refresh>0:
		preview_refresh-=dt
		if preview_refresh<=0:
			next_seed=selected_seed
			new_race()
	if is_instance_valid(touch_controls):
		touch_controls.visible=running and not in_menu
		touch_controls.weapon_available=race!=null and race.racers[0].weapon != "" and not race.racers[0].crashed
		touch_controls.reset_available=race!=null and race.can_reset(race.racers[0])
	navigate_menu(dt)
	process_pause(dt)
	probe_clock+=dt
	if probe_clock>=.05:
		probe_clock=0
		write_probe()
	if race == null: return
	if running or (in_menu and not local_paused):
		world.update_ships()
		for view in views: world.update_camera(view.camera,view.index,dt,false,running and not in_menu)
	for view in views:
		if not local_paused: update_speed_effects(view,dt)
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
			if absf(input.steer)>.25 or input.throttle>.25 or input.brake or input.boost or input.fire or input.left or input.right:
				bridge._send({"type":"controller_input","session":bridge.session,"controller":token})
	if not capture_path.is_empty():
		frame_number+=1
		var now := Time.get_ticks_usec()
		if frame_number>30: frame_times.append((now-last_frame_usec)/1000.0)
		last_frame_usec=now
		if frame_number==capture_frame:
			capture.call_deferred()

static func configure_viewport_aa(viewport:Viewport,render_quality:float)->void:
	# Godot 4.5 Mobile cannot resolve readable depth with MSAA. FXAA keeps
	# edges softened while allowing nozzle occlusion and heat depth rejection.
	var mobile:bool=RenderingServer.get_current_rendering_method()=="mobile"
	viewport.msaa_3d=Viewport.MSAA_2X if render_quality>=.8 and not mobile else Viewport.MSAA_DISABLED
	viewport.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA if render_quality>=.8 and mobile else Viewport.SCREEN_SPACE_AA_DISABLED

func update_speed_effects(view:Dictionary,dt:float)->void:
	var p:Dictionary=race.racers[view.index]
	var active:bool=running and not in_menu and race.countdown<=0 and p.recovery<=0 and not p.finished and not p.crashed
	var rush:float=view.camera.get_meta("speed_rush",0.)
	var boost:float=view.camera.get_meta("speed_boost",0.)
	var surge:float=view.camera.get_meta("speed_surge",0.)
	var amount:=rush*(.05+boost*.042+surge*.014)
	view.blur.set_shader_parameter("amount",amount if quality>=.8 and active else 0.)
	view.blur.set_shader_parameter("warp",p.warp_fx if active else 0.)
	view.blur.set_shader_parameter("emp",minf(1.,p.emp_time*4.) if active else 0.)
	view.blur.set_shader_parameter("jam",Race.Weapons.emp_glitch(p) if active else 0.)
	view.blur.set_shader_parameter("race_time",race.vfx_clock)
	view.speed_effects.update_effects(view.camera,dt,active,quality<.8)

func capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_path)
	frame_times.sort()
	var sum:=0.0
	for value in frame_times: sum+=value
	print("SPACERACER_RENDER ",JSON.stringify({"views":views.size(),"frames":frame_times.size(),"mean_ms":sum/maxi(1,frame_times.size()),
		"p95_ms":frame_times[int(frame_times.size()*.95)] if not frame_times.is_empty() else 0,
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"capture":capture_path}))
	get_tree().quit()

func process_pause(dt:float)->void:
	var held:=Input.is_physical_key_pressed(KEY_ESCAPE)
	if bridge.launched_by_daemon:
		for token in bridge.frames:
			held=held or Bridge.pressed(bridge.frame(token),7)
	if not held:
		back_release=minf(1,back_release+dt)
	elif back_release>=1:
		back_release=0
		if bridge.launched_by_daemon:
			if running: bridge.request_overlay()
		elif local_paused: start_selected()
		elif not in_menu: pause_local()

func resume_local()->void:
	local_paused=false
	in_menu=false
	running=true
	for view in views: view.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	if is_instance_valid(menu):
		ui.remove_child(menu)
		menu.queue_free()
	menu_sticks.clear()
	menu_holds.clear()

func pause_local()->void:
	if local_paused or in_menu: return
	local_paused=true
	running=false
	in_menu=true
	for view in views: view.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	menu_sticks.clear()
	menu_holds.clear()
	if is_instance_valid(touch_controls): touch_controls.clear_input()
	selected_seed=race.track.seed_value
	pause_settings={"players":human_count,"biome":race.track.biome,"difficulty":race.track.difficulty,"seed":selected_seed}
	make_menu()

func menu_race_changed()->bool:
	return local_paused and pause_settings!={"players":human_count,"biome":biome,"difficulty":difficulty,"seed":selected_seed}

func assign_local_controllers()->void:
	if bridge==null or bridge.launched_by_daemon or race==null: return
	var pads:=Input.get_connected_joypads()
	# Keep existing assignments; fill only disconnected seats, including late pairing.
	var used:Array=[]
	for p in race.racers:
		if not p.bot and pads.has(p.get("device",-1)): used.append(p.device)
	for p in race.racers:
		if p.bot or pads.has(p.get("device",-1)): continue
		p.device=-1
		for device in pads:
			if not used.has(device):
				p.device=device
				used.append(device)
				break

func _notification(what:int)->void:
	if what==NOTIFICATION_APPLICATION_PAUSED or what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		menu_holds.clear();menu_sticks.clear()
		if mobile_mode and running and not bridge.launched_by_daemon: pause_local()
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if local_paused: start_selected()
		elif not in_menu: pause_local()
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()

func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F8:
			cheats.enabled=not cheats.enabled;dev_label.visible=cheats.enabled
			get_viewport().set_input_as_handled();return
		if cheats.enabled and running and not in_menu and cheats.KEYS.has(event.keycode):
			cheats.grant(race,event.keycode)
			get_viewport().set_input_as_handled();return
	if not bridge.launched_by_daemon and not in_menu and event is InputEventJoypadButton and event.button_index==JOY_BUTTON_START and event.pressed:
		get_viewport().set_input_as_handled()
		pause_local()
		return
	if not in_menu or bridge.launched_by_daemon: return
	if event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_X]:
		var key:=Vector2i(event.device,event.button_index)
		if event.pressed:
			if not menu_holds.has(key): menu_holds[key]={"elapsed":0.,"fired":false}
		else: menu_holds.erase(key)
		get_viewport().set_input_as_handled()
		return
	var direction:=Vector2i.ZERO
	if event is InputEventKey and event.pressed:
		direction={KEY_UP:Vector2i.UP,KEY_DOWN:Vector2i.DOWN,KEY_LEFT:Vector2i.LEFT,KEY_RIGHT:Vector2i.RIGHT}.get(event.keycode,Vector2i.ZERO)
	if direction!=Vector2i.ZERO:
		move_menu(direction)
		get_viewport().set_input_as_handled()
		return
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
	update_menu_holds(dt)
	if not in_menu: return
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
	move_menu(direction)

func update_menu_holds(dt:float)->void:
	if is_instance_valid(menu_hold_bar): menu_hold_bar.modulate.a=0.
	if is_instance_valid(menu_hold_hint): menu_hold_hint.text="Hold 1s · X Random race · D-pad ← → Track / ↑ ↓ Level"
	# Conflicting holds never combine, and each press can act only once.
	if menu_holds.size()!=1:
		for state:Dictionary in menu_holds.values(): state.elapsed=0.
		return
	var key:Vector2i=menu_holds.keys()[0]
	var state:Dictionary=menu_holds[key]
	state.elapsed=minf(MENU_HOLD_SECONDS,state.elapsed+dt)
	if is_instance_valid(menu_hold_bar):
		menu_hold_bar.modulate.a=1.;menu_hold_bar.value=state.elapsed/MENU_HOLD_SECONDS
	if is_instance_valid(menu_hold_hint):
		menu_hold_hint.text={JOY_BUTTON_X:"New random race",JOY_BUTTON_DPAD_RIGHT:"Next track",JOY_BUTTON_DPAD_LEFT:"Previous track",JOY_BUTTON_DPAD_UP:"Harder",JOY_BUTTON_DPAD_DOWN:"Easier"}[key.y]
	if state.fired or state.elapsed<MENU_HOLD_SECONDS: return
	state.fired=true
	match key.y:
		JOY_BUTTON_X: start_random_race()
		JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_LEFT:
			randomize_scenery()
			adjust_menu("seed",1 if key.y==JOY_BUTTON_DPAD_RIGHT else -1)
		JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN:
			var index:=Race.Track.DIFFICULTIES.find(difficulty)
			var step:=1 if key.y==JOY_BUTTON_DPAD_UP else -1
			if index+step in range(Race.Track.DIFFICULTIES.size()): adjust_menu("difficulty",step)

func move_menu(direction:Vector2i)->void:
	var focused:=get_viewport().gui_get_focus_owner()
	if focused==null or not menu.is_ancestor_of(focused): return
	if direction.x!=0:
		adjust_menu(str(focused.get_meta("menu_id","")),direction.x)
	else:
		finish_seed_edit()
		var index:=menu_rows.find(focused)
		menu_rows[posmod(index+direction.y,menu_rows.size())].grab_focus()

func adjust_menu(id:String,step:int)->void:
	finish_seed_edit()
	if id in ["biome","difficulty","seed"]: preview_refresh=.4
	match id:
		"players": human_count=posmod(human_count-1+step,4)+1
		"biome": biome=Race.Track.BIOMES[posmod(Race.Track.BIOMES.find(biome)+step,Race.Track.BIOMES.size())]
		"difficulty": difficulty=Race.Track.DIFFICULTIES[posmod(Race.Track.DIFFICULTIES.find(difficulty)+step,3)]
		"seed": selected_seed=posmod(selected_seed-1+step,MAX_SEED)+1;finish_seed_edit()
		"graphics":
			var levels:=[.6,.8,1.0]
			quality=levels[posmod(levels.find(quality)+step,3)]
			if quality<.8: bounce_lighting=false
			world.bounce_lighting=bounce_lighting
			layout_views()
		"lighting":
			if not world.advanced_renderer: return
			bounce_lighting=not bounce_lighting
			if bounce_lighting: quality=maxf(quality,.8)
			world.bounce_lighting=bounce_lighting
			layout_views()
	refresh_menu_values()

func refresh_menu_values()->void:
	if is_instance_valid(track_character): track_character.text=Race.Track.Profiles.title(selected_seed)
	for row in menu_rows:
		if not is_instance_valid(row) or not row is Button: continue
		match str(row.get_meta("menu_id","")):
			"race": row.text=("Restart" if menu_race_changed() else "Resume") if local_paused else "Race"
			"players": row.text="Players                         %d"%human_count
			"biome": row.text="World                           %s"%("The Cell" if biome=="cell" else biome.capitalize())
			"difficulty": row.text="Level                            %s"%difficulty.capitalize()
			"graphics": row.text="Graphics                       %s"%{.6:"Performance",.8:"Balanced",1.0:"High"}.get(quality,"Balanced")
			"lighting": row.text="Lighting                         %s"%("SDFGI" if bounce_lighting else "Direct")

func _unhandled_input(event:InputEvent)->void:
	if bridge.launched_by_daemon: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ENTER and in_menu: start_selected()
		elif event.keycode==KEY_F2 and in_menu:
			human_count=human_count%4+1
			make_menu()
		elif event.keycode==KEY_F5 and not in_menu: new_race(true)

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
	for view in views: view.hud.visible=false
	var focus_id:="race"
	if not is_instance_valid(menu): selected_seed=race.track.seed_value
	if is_instance_valid(menu):
		var focused:=get_viewport().gui_get_focus_owner()
		if focused and menu.is_ancestor_of(focused): focus_id=str(focused.get_meta("menu_id","race"))
		ui.remove_child(menu)
		menu.queue_free()
	menu_rows.clear()
	menu=Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var shade:=TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shade.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	var gradient:=Gradient.new()
	gradient.offsets=PackedFloat32Array([.1,.78])
	gradient.colors=PackedColorArray([Color(.015,.025,.045,.93),Color(.015,.025,.045,.08)])
	var fade:=GradientTexture2D.new();fade.gradient=gradient;fade.width=256;fade.height=1
	fade.fill_from=Vector2.ZERO;fade.fill_to=Vector2.RIGHT
	shade.texture=fade
	menu.add_child(shade)
	var content:=VBoxContainer.new()
	content.position=Vector2(90,55)
	content.size.x=480
	content.add_theme_constant_override("separation",10)
	menu.add_child(content)
	menu_label(content,"SPACERACER",58,Color("edf7ff"))
	var start:=menu_button(content,"race","Race",start_selected,true)
	menu_button(content,"random_race","New random race",start_random_race)
	var settings:=["players","biome","difficulty","seed","graphics"]
	if world.advanced_renderer: settings.append("lighting")
	for id in settings:
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",6)
		content.add_child(row)
		var left:=Button.new()
		left.text="‹"
		left.custom_minimum_size=Vector2(52,54)
		left.focus_mode=Control.FOCUS_NONE
		style_button(left)
		left.pressed.connect(adjust_menu.bind(id,-1))
		row.add_child(left)
		if id=="seed":
			seed_input=LineEdit.new()
			seed_input.set_meta("menu_id",id)
			seed_input.text="%05d"%selected_seed
			seed_input.max_length=5
			seed_input.select_all_on_focus=true
			seed_input.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_NUMBER
			seed_input.custom_minimum_size=Vector2(364,54)
			seed_input.alignment=HORIZONTAL_ALIGNMENT_CENTER
			seed_input.add_theme_font_size_override("font_size",24)
			seed_input.add_theme_stylebox_override("normal",menu_style(Color(1,1,1,.045),Color(1,1,1,.12)))
			seed_input.add_theme_stylebox_override("focus",menu_style(Color.TRANSPARENT,Color("7de9d6")))
			seed_input.text_changed.connect(seed_text_changed)
			seed_input.focus_exited.connect(finish_seed_edit)
			seed_input.text_submitted.connect(func(_value:String): start_selected())
			row.add_child(seed_input)
			menu_rows.append(seed_input)
		else:
			menu_button(row,id,"",adjust_menu.bind(id,1)).custom_minimum_size.x=364
		var right:=Button.new()
		right.text="›"
		right.custom_minimum_size=Vector2(52,54)
		right.focus_mode=Control.FOCUS_NONE
		style_button(right)
		right.pressed.connect(adjust_menu.bind(id,1))
		row.add_child(right)
		if id=="seed":
			track_character=Label.new()
			track_character.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			track_character.add_theme_font_size_override("font_size",16)
			track_character.add_theme_color_override("font_color",Color("7de9d6"))
			content.add_child(track_character)
	menu_button(content,"controls","Controls & credits",func(): show_menu_controls=not show_menu_controls;make_menu())
	if local_paused:
		menu_button(content,"restart","Restart race",func(): finish_seed_edit();next_seed=selected_seed;start_local())
	if show_menu_controls:
		var reference:=PanelContainer.new()
		reference.position=Vector2(610,150)
		reference.add_theme_stylebox_override("panel",menu_style(Color(.02,.035,.05,.92)))
		menu.add_child(reference)
		var help:=VBoxContainer.new()
		reference.add_child(help)
		menu_label(help,"CONTROLS",24)
		menu_label(help,"RT / A  Throttle     LT  Brake     B  Boost\nX  Use pickup     LB / RB  Side bump\nLeft stick  Steer / yaw\nRight stick  Strafe / roll\nEither stick ↑ ↓  Grip / pitch\nY  Reset     Start  Pause\n\nKeyboard  WASD · Space · Q / E bump · 1 · X pickup",20)
		var credits:=RichTextLabel.new()
		credits.bbcode_enabled=true
		credits.fit_content=true
		credits.custom_minimum_size.x=470
		credits.add_theme_font_size_override("normal_font_size",14)
		credits.text="\nFOREST ART · [url=https://creativecommons.org/licenses/by/4.0/]CC BY 4.0[/url]\n[url=https://sketchfab.com/3d-models/pine-tree-d45218a3fab349e5b1de040f29e7b6f9]Pine Tree[/url] — evolveduk\n[url=https://sketchfab.com/3d-models/tree-bake-upload-4e78d13152cf4214a256230765f6d6d3]Tree Bake Upload[/url] — restlessmonkey\n[url=https://github.com/GamesNotDeveloped/godot-forest-demo]Godot forest demo[/url] — GamesNotDeveloped\nAdapted materials, textures and scale for SpaceRacer."
		credits.meta_clicked.connect(func(url:Variant): OS.shell_open(str(url)))
		help.add_child(credits)
	menu_label(content,"Stick  Select / adjust     Start  Play / resume",14,Color("91a8b7"))
	menu_hold_hint=Label.new();menu_hold_hint.add_theme_font_size_override("font_size",14)
	menu_hold_hint.add_theme_color_override("font_color",Color("91a8b7"));content.add_child(menu_hold_hint)
	menu_hold_bar=ProgressBar.new();menu_hold_bar.max_value=1.;menu_hold_bar.show_percentage=false
	menu_hold_bar.custom_minimum_size=Vector2(480,3);menu_hold_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var hold_background:=StyleBoxFlat.new();hold_background.bg_color=Color(1,1,1,.08)
	var hold_fill:=StyleBoxFlat.new();hold_fill.bg_color=Color("7de9d6")
	menu_hold_bar.add_theme_stylebox_override("background",hold_background)
	menu_hold_bar.add_theme_stylebox_override("fill",hold_fill)
	content.add_child(menu_hold_bar);update_menu_holds(0.)
	refresh_menu_values()
	for i in range(menu_rows.size()):
		var row:=menu_rows[i]
		row.focus_neighbor_top=menu_rows[posmod(i-1,menu_rows.size())].get_path()
		row.focus_neighbor_bottom=menu_rows[(i+1)%menu_rows.size()].get_path()
		row.focus_neighbor_left=row.get_path()
		row.focus_neighbor_right=row.get_path()
		if row.get_meta("menu_id")==focus_id: row.grab_focus()
	if get_viewport().gui_get_focus_owner()==null: start.grab_focus()

func menu_button(parent:Node,id:String,title:String,action:Callable,primary:bool=false)->Button:
	var button:=Button.new()
	button.set_meta("menu_id",id)
	button.text=title
	button.custom_minimum_size=Vector2(480,54)
	style_button(button,primary)
	button.pressed.connect(action)
	parent.add_child(button)
	menu_rows.append(button)
	return button

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
	bridge.notify_progress(session,5,"Building track")
	new_race()
	bridge.notify_progress(session,65,"Warming renderer")
	# Draw at real display dimensions before Ready. Park off-screen while warming.
	if not headless:
		get_window().mode=Window.MODE_WINDOWED
		for warmup in range(60):
			await RenderingServer.frame_post_draw
			if bridge.session!=session: return
	if bridge.session!=session: return
	bridge.notify_progress(session,100,"Ready")
	quiet_window()
	managed_rendering(false)
	bridge.ready_for_session(session)
	Engine.max_fps=30

func managed_rendering(enabled:bool)->void:
	for view in views:
		view.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
		view.visor.suspended=not enabled
		view.visor.sync_visibility()

func start_managed(_session:String)->void:
	managed_rendering(true)
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
	managed_rendering(false)
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
	elif key=="difficulty" and str(value) in Race.Track.DIFFICULTIES: difficulty=str(value)
	elif key=="biome" and str(value) in Race.Track.BIOMES: biome=str(value)
	elif key=="seed": next_seed=clampi(int(value),0,MAX_SEED)
	elif key=="quality":
		quality={"performance":.6,"balanced":.8,"high":1.0}.get(str(value),1.0)
		layout_views()

func setup_audio()->void:
	missile_sound=preload("res://src/missile_audio.gd").new();add_child(missile_sound)
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
	missile_sound.update(race,views,running and not in_menu,sound_enabled)
	if race==null or not running or race.over or race.countdown>0:
		engine_sound.volume_db=-80
		return
	var speed:=0.0
	for view in views: speed=maxf(speed,race.racers[view.index].speed)
	engine_sound.pitch_scale=.65+speed/130
	engine_sound.volume_db=-28+speed/80

func write_probe()->void:
	var path:=OS.get_environment("SPACERACER_PROBE_PATH")
	if path.is_empty(): return
	var snapshot:Array=[]
	if race:
		for p in race.racers:
			var copy:Dictionary=p.duplicate()
			for key in ["time","best_lap"]:
				if not is_finite(copy[key]): copy[key]=null
			if is_instance_valid(world) and world.ships.size()>snapshot.size():
				var face:RefCounted=world.ships[snapshot.size()].get_meta("pilot_face")
				copy.face_revision=face.revision
				copy.face_signature=face.signature
			snapshot.append(copy)
	var state:Dictionary={"phase":bridge.phase,"running":running,
		"speed_travel":views.map(func(view):return view.speed_effects.travel),
		"speed_camera_clock":views.map(func(view):return view.camera.get_meta("speed_clock",0.)),
		"difficulty":race.track.difficulty if race else "", "next_difficulty":difficulty,
		"biome":race.track.biome if race else "", "next_biome":biome,
		"visible":get_window().mode!=Window.MODE_MINIMIZED and get_window().position.x> -10000,
		"sound_enabled":sound_enabled,"muted":AudioServer.is_bus_mute(0),"clock":race.clock if race else -1,"countdown":race.countdown if race else -1,"vfx_clock":race.vfx_clock if race else -1,
		"racers":snapshot,"views":views.size(),"session":bridge.session,
		"city_time":world.scenery.animation_time if race and is_instance_valid(world) else 0.0,
		"traffic_position":str(world.scenery.air_traffic.car_frame(world.scenery.air_traffic.cars[0]).origin) if race and is_instance_valid(world) and world.scenery.traffic.instance_count>0 else "",
		"tunnel_time":world.tunnel_material.get_shader_parameter("race_time") if race and is_instance_valid(world) else 0.0}
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(state))

func _exit_tree()->void:
	if is_instance_valid(engine_sound):
		engine_sound.stop()
		engine_sound.stream=null
