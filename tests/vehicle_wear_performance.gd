extends SceneTree
func _initialize()->void: root.unfocusable=true;call_deferred("run")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	for players in [1,2,4]:
		game.human_count=players;game.biome="city";game.difficulty="hard";game.next_seed=31;game.start_local()
		game.set_process(false);game.set_physics_process(false);game.running=false
		game.race.countdown=0.;game.race.clock=20.;game.race.vfx_clock=20.
		for i in range(game.race.racers.size()):
			var p:Dictionary=game.race.racers[i]
			p.distance=740.+i*25.;p.x=(i%2)*6.-3.;p.startup=1.;p.engine_power=.65;p.speed=260.;p.energy=8.
			if i==0: p.color="#bf3334"
		game.world.update_ships()
		for view in game.views:
			game.world.update_camera(view.camera,view.index,0.,true);view.hud.queue_redraw()
			RenderingServer.viewport_set_measure_render_time(view.viewport.get_viewport_rid(),true)
		var results:={false:[],true:[]}
		for enabled in [false,true,true,false]:
			for ship in game.world.ships:
				for mat in ship.get_meta("damage_materials"): mat.set_shader_parameter("wear_enabled",enabled)
				ship.get_meta("damage_smoke").visible=enabled
			for i in range(35): await process_frame
			for frame in range(60):
				await process_frame
				var cost:=0.
				for view in game.views: cost+=RenderingServer.viewport_get_measured_render_time_gpu(view.viewport.get_viewport_rid())
				results[enabled].append(cost)
			if enabled:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/vehicle-wear-game-%d.png"%players)
		for enabled in [false,true]:
			results[enabled].sort()
			print("WEAR_GPU players=",players," enabled=",enabled," median_ms=",results[enabled][60]," p95_ms=",results[enabled][114]," viewport=",game.views[0].viewport.size)
		var cpu:Array[int]=[]
		for tick in range(120):
			var start:=Time.get_ticks_usec()
			for i in range(game.race.racers.size()):
				var p:Dictionary=game.race.racers[i];p.energy=8.+tick*.01
				game.world.Ship.Wear.update(game.world.ships[i],p,20.+tick/120.)
			cpu.append(Time.get_ticks_usec()-start)
		cpu.sort();print("WEAR_CPU all_cars=",game.race.racers.size()," median_us=",cpu[60]," p95_us=",cpu[114])
	game.queue_free();await process_frame;quit()
