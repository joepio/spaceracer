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

func tap_key(keycode:int)->void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=keycode;event.pressed=down
		Input.parse_input_event(event);await process_frame

func hold(button:int,seconds:float,release:bool=true)->void:
	var event:=InputEventJoypadButton.new();event.button_index=button;event.pressed=true
	game._input(event)
	game.update_menu_holds(seconds)
	if release: event.pressed=false;game._input(event)

func row(id:String)->Control:
	for control in game.menu_rows:
		if control.get_meta("menu_id")==id: return control
	return null

func run()->void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(focus_id()=="race","Race focused initially")
	check(game.seed_input.text.length()==5 and int(game.seed_input.text)==game.race.track.seed_value,"Preview code displayed")
	check(game.track_character.text==game.race.track.layout,"Seed displays the track character")
	await stick(0,.9)
	check(focus_id()=="random_race","New random race is one row below Play")
	await stick(0,.9)
	check(focus_id()=="players","Down selects player row")
	await stick(.9,0)
	check(game.human_count==2 and focus_id()=="players","Right immediately adjusts count")
	await stick(-.9,0)
	check(game.human_count==1,"Left restores solo without A")
	await stick(0,.9)
	check(focus_id()=="biome","Down selects world")
	await stick(.9,0)
	check(game.biome=="forest" and focus_id()=="biome","Right immediately selects Forest")
	await stick(.9,0)
	check(game.biome=="cell" and row("biome").text.ends_with("The Cell"),"Right selects The Cell")
	await stick(.9,0)
	check(game.biome=="city","World selection wraps after Cell")
	await stick(-.9,0)
	check(game.biome=="cell","Left wraps back to Cell")
	await stick(-.9,0)
	check(game.biome=="forest","Left returns to Forest")
	await stick(0,.9)
	await stick(.9,0)
	check(game.difficulty=="hard" and focus_id()=="difficulty","Right immediately selects Hard")
	await stick(0,.9)
	check(focus_id()=="seed","Down selects seed")
	game.selected_seed=99999
	game.finish_seed_edit()
	await stick(.9,0)
	check(game.selected_seed==1 and game.seed_input.text=="00001","Next seed wraps")
	await stick(-.9,0)
	check(game.selected_seed==99999,"Previous seed wraps")
	await stick(0,0)
	await press(JOY_BUTTON_A)
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
	check(game.selected_seed==421,"Seed still supports direct typing")
	await press(JOY_BUTTON_DPAD_DOWN)
	check(focus_id()=="seed" and game.difficulty=="hard","A short D-pad tap cannot change settings")
	await press(JOY_BUTTON_START)
	check(game.running and game.views.size()==1,"Start launches solo")
	check(game.race.track.seed_value==421 and game.race.track.biome=="forest" and game.race.track.difficulty=="hard","All selected settings applied")
	check(not game.race.racers[0].bot and AudioServer.is_bus_mute(0),"Player control and muted audio preserved")
	var original:RefCounted=game.race
	await press(JOY_BUTTON_BACK)
	check(not game.local_paused,"Back ignored")
	await press(JOY_BUTTON_START)
	check(game.local_paused and focus_id()=="race" and row("race").text=="Resume","Shared menu opens on Resume")
	check(game.views.all(func(view):return not view.visor.visible and view.visor.surface.render_target_update_mode==SubViewport.UPDATE_DISABLED),"Pause hides the entire visor and stops instrument rendering")
	check(game.views.all(func(view):return view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED),"Pause retains the last rendered race frame")
	var frozen:Image
	if "--render" in OS.get_cmdline_user_args(): frozen=game.views[0].viewport.get_texture().get_image()
	check(row("players")!=null and row("seed")!=null and row("biome")!=null,"Pause exposes the same settings")
	var clock:float=game.race.vfx_clock
	for frame in range(8): await process_frame
	check(game.race.vfx_clock==clock,"Pause freezes effects and simulation")
	if frozen!=null:
		check(frozen.get_data()==game.views[0].viewport.get_texture().get_image().get_data(),"Paused world pixels remain exactly frozen")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/pause-frozen.png")
	await press(JOY_BUTTON_START)
	check(game.race==original and game.running,"Unchanged Start resumes current race")
	check(game.views.all(func(view):return view.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS),"Resume restarts world rendering")
	check(game.views.all(func(view):return view.visor.visible and view.visor.surface.render_target_update_mode==SubViewport.UPDATE_ALWAYS),"Resume restores the visor projection")
	await press(JOY_BUTTON_START)
	row("seed").grab_focus()
	await tap_key(KEY_RIGHT)
	check(game.selected_seed==422 and row("race").text=="Restart","Pending change marks primary Restart")
	check(game.track_character.text=="Underpass","Changing seed immediately previews its new character while paused")
	check(game.race==original and game.race.track.seed_value==421 and game.local_paused,"Adjusting settings does not rebuild paused race")
	await tap_key(KEY_LEFT)
	check(row("race").text=="Resume","Undoing changes restores Resume")
	row("graphics").grab_focus()
	await tap_key(KEY_RIGHT)
	check(game.quality==.6 and row("race").text=="Resume","Graphics adjusts without losing race")
	check(game.views[0].visor.surface.size.x>game.views[0].viewport.size.x,"Performance keeps instruments sharp at output resolution")
	if game.world.advanced_renderer:
		row("lighting").grab_focus()
		await tap_key(KEY_RIGHT)
		check(game.bounce_lighting and game.world.scene_environment.sdfgi_enabled and game.quality>=.8,"Lighting row enables SDFGI and a supported graphics tier")
		check(game.race==original and game.local_paused and row("race").text=="Resume","Lighting comparison preserves the paused race")
		await tap_key(KEY_LEFT)
		check(not game.bounce_lighting and not game.world.scene_environment.sdfgi_enabled,"Lighting row restores the direct comparison")
	row("players").grab_focus()
	await tap_key(KEY_RIGHT)
	await press(JOY_BUTTON_START)
	check(game.views.size()==2 and game.race!=original and game.race.track.seed_value==421,"Start applies pending player count with same seed")
	check(game.views[0].visor.surface!=game.views[1].visor.surface,"Each split-screen pilot owns a separate instrument surface")
	await press(JOY_BUTTON_START)
	var previous:RefCounted=game.race
	var seed_before:int=game.selected_seed
	await hold(JOY_BUTTON_DPAD_RIGHT,.95)
	check(game.selected_seed==seed_before,"A partial hold is canceled on release")
	await hold(JOY_BUTTON_DPAD_RIGHT,.6,false)
	check(game.selected_seed==seed_before,"Separate holds do not accumulate")
	game.update_menu_holds(.41)
	check(game.selected_seed==seed_before+1 and game.race==previous and game.local_paused,"Full hold previews next seed without discarding frozen race")
	game.update_menu_holds(2.)
	check(game.selected_seed==seed_before+1,"Holding longer cannot cycle repeatedly")
	await hold(JOY_BUTTON_DPAD_RIGHT,0.)
	await hold(JOY_BUTTON_DPAD_LEFT,1.01)
	check(game.selected_seed==seed_before,"Hold left selects previous seed")
	await hold(JOY_BUTTON_DPAD_DOWN,1.01)
	check(game.difficulty=="normal","Hold down lowers difficulty")
	await hold(JOY_BUTTON_DPAD_UP,1.01)
	await hold(JOY_BUTTON_DPAD_UP,1.01)
	check(game.difficulty=="hard","Hold up raises difficulty without wrapping hard to easy")
	await hold(JOY_BUTTON_X,.99)
	check(game.race==previous and game.local_paused,"Short random-race hold cannot discard race")
	seed(73)
	var random_world:String=game.Race.Track.BIOMES.pick_random()
	seed(73)
	game.biome=game.Race.Track.BIOMES[(game.Race.Track.BIOMES.find(random_world)+1)%3]
	await hold(JOY_BUTTON_X,1.01)
	check(game.running and not game.local_paused and game.race!=previous and game.race.track.seed_value!=seed_before,"Full X hold immediately starts a different random track")
	check(game.human_count==2 and game.race.track.biome==random_world and game.biome==random_world and game.race.track.difficulty=="hard" and game.laps==3,"Quick random race rolls scenery while preserving players, difficulty and laps")
	await press(JOY_BUTTON_START)
	seed_before=game.selected_seed
	row("random_race").grab_focus();await press(JOY_BUTTON_A)
	check(game.running and game.race.track.seed_value!=seed_before and game.views.size()==2,"Random-race menu button works with A and preserves player count")
	seed(91);random_world=game.Race.Track.BIOMES.pick_random();seed(91)
	await tap_key(KEY_F5)
	check(game.race.track.biome==random_world and game.biome==random_world,"F5 rolls scenery for the next track")
	await press(JOY_BUTTON_START)
	var restart_world:String=game.race.track.biome
	var restart_seed:int=game.race.track.seed_value
	row("restart").grab_focus();await press(JOY_BUTTON_A)
	check(game.race.track.biome==restart_world and game.race.track.seed_value==restart_seed,"Restart preserves the same track and scenery")
	seed(117);random_world=game.Race.Track.BIOMES.pick_random();seed(117)
	game.race.over=true;game.results_clock=8.
	game._physics_process(0.)
	check(game.race.track.biome==random_world and game.race.track.difficulty=="hard" and game.human_count==2,"Automatic next race rolls scenery and keeps race settings")
	print("MENU_TESTS ",failures," failures")
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
