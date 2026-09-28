extends SceneTree
var game:Node
var output:="C:/dev/ion-rush-captures/gi/city-haze"
var current:Dictionary={}
func _initialize()->void:
	root.unfocusable=true
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func apply_haze(after:bool)->void:
	var env:Environment=game.world.scene_environment
	for key in current:
		if key!="horizon": env.set(key,current[key])
	var horizon:Vector3=current.horizon
	if not after:
		env.fog_light_color=Color("182437")
		env.fog_light_energy=.65
		env.fog_density=.00032
		env.volumetric_fog_density=.0012
		env.volumetric_fog_length=180.
		var color:=Color("0c121c").srgb_to_linear()
		horizon=Vector3(color.r,color.g,color.b)
	env.sky.sky_material.set_shader_parameter("horizon_color",horizon)
func capture(label:String)->void:
	for i in range(55): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run()->void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	for players in [1,2]:
		game.human_count=players;game.biome="city";game.next_seed=31;game.start_local()
		game.set_process(false);game.set_physics_process(false);game.running=false
		game.race.countdown=0.;game.race.clock=20.;game.race.vfx_clock=20.
		for key in ["fog_light_color","fog_light_energy","fog_density","volumetric_fog_density","volumetric_fog_length"]:
			current[key]=game.world.scene_environment.get(key)
		current.horizon=game.world.scene_environment.sky.sky_material.get_shader_parameter("horizon_color")
		for view in game.views: RenderingServer.viewport_set_measure_render_time(view.viewport.get_viewport_rid(),true)
		for fraction in [.025,.10]:
			for i in range(game.race.racers.size()):
				var p:Dictionary=game.race.racers[i];p.distance=game.race.track.length*fraction+i*25.;p.startup=1.;p.engine_power=.5;p.speed=260.
			game.world.update_ships()
			for view in game.views:
				game.world.update_camera(view.camera,view.index,0.,true);view.hud.queue_redraw()
			var results:={false:[],true:[]}
			for after in [false,true,true,false]:
				apply_haze(after)
				await capture("%dp-%s-%s"%[players,str(fraction),"after" if after else "before"])
				for i in range(40):
					await process_frame
					var cost:=0.
					for view in game.views: cost+=RenderingServer.viewport_get_measured_render_time_gpu(view.viewport.get_viewport_rid())
					results[after].append(cost)
			for after in [false,true]:
				results[after].sort();print("HAZE_GPU players=",players," position=",fraction," after=",after," median_ms=",results[after][40])
	game.queue_free();await process_frame;quit()
