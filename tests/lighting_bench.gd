extends SceneTree
## Fixed gameplay camera and frozen world, with per-viewport GPU/CPU timestamps.
var game:Node
var output:="user://lighting-bench"
var label_name:="baseline"
var players:=1
var samples:=1200
var ablation:=""
var seed_value:=31
var fraction:=.055
var moving:=false
var scripted_motion:=false
var quality:=1.0
var landmark:=""
var speed:=250.
var boost:=false
func _initialize()->void:
	root.unfocusable=true
	for arg in OS.get_cmdline_user_args():
		if arg=="--moving": moving=true
		elif arg=="--scripted-motion": moving=true;scripted_motion=true
		elif arg=="--boost": boost=true
		elif arg.begins_with("--speed="): speed=float(arg.trim_prefix("--speed="))
		elif arg.begins_with("--seed="): seed_value=int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--landmark="): landmark=arg.trim_prefix("--landmark=")
		elif arg.begins_with("--quality="): quality=float(arg.trim_prefix("--quality="))
		elif arg.begins_with("--out="): output=arg.trim_prefix("--out=")
		elif arg.begins_with("--label="): label_name=arg.trim_prefix("--label=")
		elif arg.begins_with("--views="): players=int(arg.trim_prefix("--views="))
		elif arg.begins_with("--samples="): samples=int(arg.trim_prefix("--samples="))
		elif arg.begins_with("--ablation="): ablation=arg.trim_prefix("--ablation=")
		elif arg.begins_with("--fraction="): fraction=float(arg.trim_prefix("--fraction="))
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func stats(values:Array[float])->Dictionary:
	values.sort()
	var total:=0.
	for v in values: total+=v
	return {"mean":total/values.size(),"p50":values[int(values.size()*.5)],"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)],"max":values[-1]}
func run()->void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.demo=moving
	game.quality=quality
	game.human_count=players
	game.next_seed=seed_value
	game.start_local()
	if landmark=="corner":
		for i in range(game.race.track.nodes.size()):
			var node:Dictionary=game.race.track.nodes[i]
			if absf(node.curve)>.0035 and node.feature=="ribbon" and not node.loop:
				fraction=fposmod(i*game.race.track.step-180.,game.race.track.length)/game.race.track.length
				break
	if landmark in ["loop","tunnel","open","halfpipe","tube","split","jump","flight","chicane","narrows"]:
		var indices:Array=[]
		for i in range(game.race.track.nodes.size()):
			var node:Dictionary=game.race.track.nodes[i]
			var matches:bool=node[landmark] if landmark in ["loop","tunnel"] else node.feature==landmark
			if matches: indices.append(i)
			elif not indices.is_empty(): break
		if not indices.is_empty(): fraction=float(indices[indices.size()/2])/game.race.track.nodes.size()
		if landmark in ["jump","flight"]:
			for jump in game.race.track.jumps:
				if jump.kind==landmark: fraction=(jump.takeoff-90.)/game.race.track.length
	game.running=false
	game.race.countdown=0
	game.race.clock=20.
	game.race.vfx_clock=20.
	game.set_process(false)
	game.set_physics_process(false)
	for i in range(game.race.racers.size()):
		var p:Dictionary=game.race.racers[i]
		p.distance=game.race.track.length*fraction+[0.,18.,62.,105.,145.,190.][i]
		p.x=[0.,9.,-9.,5.,-6.,3.][i]
		p.startup=1.
		p.engine_power=1.
		p.thrust=1.
		p.acceleration=95.
		p.speed=speed
		p.boost=1. if boost else 0.
	game.world.update_ships()
	var viewports:Array[RID]=[root.get_viewport_rid()]
	for view in game.views:
		game.world.update_camera(view.camera,view.index,0,true)
		game.running=true
		game.update_speed_effects(view,.21)
		game.running=false
		viewports.append(view.viewport.get_viewport_rid())
		view.hud.queue_redraw()
	for rid in viewports: RenderingServer.viewport_set_measure_render_time(rid,true)
	var env:Environment=game.world.scene_environment
	if ablation=="no-volumetrics": env.volumetric_fog_enabled=false
	if ablation=="no-box-reflections":
		for material in game.world.road_sections: material.set_shader_parameter("box_count",0)
	if ablation=="no-ssil": env.ssil_enabled=false
	if ablation=="with-ssil": env.ssil_enabled=true
	if ablation=="no-ssr": env.ssr_enabled=false
	if ablation=="no-shadows": disable_shadows(game.world)
	if ablation=="two-cascades" and is_instance_valid(game.world.forest_sun):
		game.world.forest_sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		game.world.forest_sun.directional_shadow_split_1=.12
	if ablation=="legacy-shadows" and is_instance_valid(game.world.forest_sun):
		game.world.forest_sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		game.world.forest_sun.directional_shadow_max_distance=380. if players==1 else 220.
		game.world.forest_sun.directional_shadow_blend_splits=false
		game.world.forest_sun.directional_shadow_split_1=.1
		game.world.forest_sun.directional_shadow_fade_start=.8
		game.world.forest_sun.directional_shadow_pancake_size=20.
	if ablation in ["no-jet-optics","no-jet-heat"]:
		for ship in game.world.ships:
			for side in [-1,1]:
				ship.get_node("EngineHeat%d"%side).visible=false
				if ablation=="no-jet-optics": ship.get_node("EngineFlare%d"%side).visible=false
	if ablation=="no-probes":
		for probe in game.world.showpiece.probes: probe.intensity=0.
	if ablation=="no-speed-post" and not moving:
		for view in game.views:
			view.blur.set_shader_parameter("amount",0.)
			view.speed_effects.visible=false
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Warm shader pipelines, every cubemap face and GPU clocks before timing.
	var warm_end:=Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<warm_end: await RenderingServer.frame_post_draw
	if moving:
		game.running=true
		game.set_process(not scripted_motion)
		game.set_physics_process(not scripted_motion)
	var frame_ms:Array[float]=[]
	var gpu_ms:Array[float]=[]
	var cpu_ms:Array[float]=[]
	var rows:=PackedStringArray(["frame,wall_ms,gpu_ms,render_cpu_ms"])
	var last:=Time.get_ticks_usec()
	var sample_start:=Time.get_unix_time_from_system()
	for i in range(samples):
		if scripted_motion:
			# Identical route and simulation time across shadow configurations.
			game._physics_process(1./120.)
			game._physics_process(1./120.)
			game._process(1./60.)
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		var wall:float=(now-last)/1000.
		last=now
		var gpu:=0.
		var cpu:=RenderingServer.get_frame_setup_time_cpu()
		for rid in viewports:
			gpu+=RenderingServer.viewport_get_measured_render_time_gpu(rid)
			cpu+=RenderingServer.viewport_get_measured_render_time_cpu(rid)
		frame_ms.append(wall);gpu_ms.append(gpu);cpu_ms.append(cpu)
		rows.append("%d,%.5f,%.5f,%.5f"%[i,wall,gpu,cpu])
	var sample_end:=Time.get_unix_time_from_system()
	var raw:=FileAccess.open(output.path_join(label_name+".csv"),FileAccess.WRITE)
	raw.store_string("\n".join(rows));raw.close()
	var result:={"moving":moving,"quality":quality,"seed":seed_value,"fraction":fraction,"views":players,"resolution":root.size,"samples":samples,"ablation":ablation,"wall_ms":stats(frame_ms),"gpu_ms":stats(gpu_ms),"render_cpu_ms":stats(cpu_ms),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_mem_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.,"device":RenderingServer.get_video_adapter_name(),"camera":str(game.views[0].camera.global_transform)}
	result.sample_start_utc=sample_start
	result.scripted_motion=scripted_motion
	result.difficulty=game.race.track.difficulty
	result.biome=game.race.track.biome
	result.speed=speed
	result.boost=boost
	result.sample_end_utc=sample_end
	result.shadow_lights=(game.world.showpiece.lights+game.world.scenery.local_lights).filter(func(light):return light.shadow_enabled).size()
	if is_instance_valid(game.world.forest_sun):
		result.sun_shadow_distance=game.world.forest_sun.directional_shadow_max_distance
		result.sun_shadow_fade=game.world.forest_sun.directional_shadow_fade_start
		result.sun_shadow_blend=game.world.forest_sun.directional_shadow_blend_splits
		result.sun_shadow_cascades=4 if game.world.forest_sun.directional_shadow_mode==DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS else 2
	result.viewport_sizes=game.views.map(func(view):return str(view.viewport.size))
	var file:=FileAccess.open(output.path_join(label_name+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	root.get_texture().get_image().save_png(output.path_join(label_name+".png"))
	print("LIGHTING_BENCH ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit()
func disable_shadows(node:Node)->void:
	if node is Light3D: node.shadow_enabled=false
	for child in node.get_children(): disable_shadows(child)
