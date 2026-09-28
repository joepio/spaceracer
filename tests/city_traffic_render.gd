extends SceneTree
func _initialize()->void: root.unfocusable=true;call_deferred("run")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	for players in [1,2,4]:
		game.human_count=players;game.biome="city";game.next_seed=31;game.start_local()
		game.set_process(false);game.set_physics_process(false);game.running=false
		game.race.countdown=0.;game.race.clock=20.;game.race.vfx_clock=20.
		for i in range(game.race.racers.size()):
			var p:Dictionary=game.race.racers[i];p.distance=740.+i*25.;p.startup=1.;p.engine_power=.5;p.speed=260.
		game.world.update_ships()
		var traffic:RefCounted=game.world.scenery.air_traffic
		print("TRAFFIC_RENDER cars=",traffic.cars.size()," lanes=",traffic.routes.size())
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
			if enabled:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/traffic-game-%d.png"%players)
		for enabled in [false,true]:
			results[enabled].sort();print("TRAFFIC_GPU players=",players," enabled=",enabled," median_ms=",results[enabled][50]," p95_ms=",results[enabled][95])
		var cpu:Array[int]=[]
		for tick in range(240):
			var start:=Time.get_ticks_usec();traffic.animate(20.+tick/120.)
			for car_index in range(6):
				var frame:Transform3D=traffic.car_frame(traffic.cars[car_index*43])
				traffic.trace(frame.origin-frame.basis.z*10.,frame.origin+frame.basis.z*10.,3.6)
			cpu.append(Time.get_ticks_usec()-start)
		cpu.sort();print("TRAFFIC_CPU animate_plus_6_nearby_sweeps median_us=",cpu[120]," p95_us=",cpu[228])
		if players==1:
			for renderer in traffic.renderers: renderer.visible=true
			var route:Dictionary=traffic.routes[0]
			for candidate in traffic.routes:
				if candidate.start.y>100. and candidate.length>route.length: route=candidate
			var car:Dictionary=traffic.cars[route.cars[route.cars.size()/2]]
			var frame:Transform3D=traffic.car_frame(car)
			game.views[0].hud.visible=false
			var camera:Camera3D=game.views[0].camera
			camera.position=frame*Vector3(16,10,-30);camera.look_at(frame.origin+frame.basis.z*70);camera.fov=62.
			for i in range(30): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/traffic-avenue.png")
	game.queue_free();await process_frame;quit()
