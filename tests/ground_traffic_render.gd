extends SceneTree
func _initialize()->void: root.unfocusable=true;call_deferred("run")
func capture(name_value:String)->void:
	for i in range(25): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/ground-"+name_value+".png")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	for players in [1,2,4]:
		game.human_count=players;game.biome="city";game.next_seed=31;game.start_local()
		game.set_process(false);game.set_physics_process(false);game.running=false
		game.race.countdown=0.;game.race.clock=20.;game.race.vfx_clock=20.
		for i in range(game.race.racers.size()):
			var p:Dictionary=game.race.racers[i];p.distance=game.race.track.length*.10+i*25.;p.startup=1.;p.engine_power=.5;p.speed=260.
		game.world.update_ships()
		var traffic:RefCounted=game.world.scenery.ground_traffic
		print("GROUND_RENDER cars=",traffic.cars.size()," routes=",traffic.routes.size()," batches=",traffic.renderers.size())
		for view in game.views:
			game.world.update_camera(view.camera,view.index,0.,true);view.hud.queue_redraw()
			RenderingServer.viewport_set_measure_render_time(view.viewport.get_viewport_rid(),true)
		var results:={false:[],true:[]}
		for enabled in [false,true,true,false]:
			for renderer in traffic.renderers: renderer.visible=enabled
			for i in range(30): await process_frame
			for i in range(50):
				await process_frame
				var cost:=0.
				for view in game.views: cost+=RenderingServer.viewport_get_measured_render_time_gpu(view.viewport.get_viewport_rid())
				results[enabled].append(cost)
			if enabled: await capture("game-%d"%players)
		for enabled in [false,true]:
			results[enabled].sort();print("GROUND_GPU players=",players," enabled=",enabled," median_ms=",results[enabled][50]," p95_ms=",results[enabled][95])
		var start:=Time.get_ticks_usec()
		for tick in range(1000):
			traffic.animate(20.+tick/120.)
			for i in range(6): traffic.trace(Vector3(i*50,20,0),Vector3(i*50+5,20,5),4.)
		print("GROUND_CPU animate_plus_six_elevated_sweeps avg_us=",float(Time.get_ticks_usec()-start)/1000.)
		if players==1:
			for renderer in traffic.renderers: renderer.visible=true
			var route:Dictionary=traffic.routes[0]
			for candidate in traffic.routes:
				if candidate.center.length_squared()<route.center.length_squared(): route=candidate
			var camera:Camera3D=game.views[0].camera;game.views[0].hud.visible=false
			camera.position=route.center+Vector3(82,110,-110);camera.look_at(route.center+Vector3(20,0,-45));camera.fov=65.
			await capture("overview")
			camera.position=route.center+Vector3(-37,8,-59);camera.look_at(route.center+Vector3(90,1,-55));camera.fov=67.
			await capture("street")
	game.queue_free();await process_frame;quit()
