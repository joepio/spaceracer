extends SceneTree
func _initialize()->void: root.unfocusable=true;call_deferred("run")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	for players in [1,2]:
		game.human_count=players;game.biome="city";game.difficulty="hard";game.next_seed=31;game.start_local()
		game.set_process(false);game.set_physics_process(false);game.running=false
		game.race.countdown=0.;game.race.clock=20.;game.race.vfx_clock=20.
		for i in range(game.race.racers.size()):
			var p:Dictionary=game.race.racers[i]
			p.distance=740.+i*25.;p.x=(i%2)*6.-3.;p.startup=1.;p.engine_power=.65;p.speed=260.
			if i==0: p.color="#bf3334";p.weapon="drone"
		game.world.update_ships()
		for view in game.views:
			game.world.update_camera(view.camera,view.index,0.,true);view.hud.queue_redraw()
			RenderingServer.viewport_set_measure_render_time(view.viewport.get_viewport_rid(),true)
		for i in range(60): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/red-racer-game-%d.png"%players)
		var gpu:Array[float]=[]
		for frame in range(120):
			await process_frame
			var cost:=0.
			for view in game.views: cost+=RenderingServer.viewport_get_measured_render_time_gpu(view.viewport.get_viewport_rid())
			gpu.append(cost)
		gpu.sort();print("RED_RACER_GPU players=",players," median_ms=",gpu[60]," p95_ms=",gpu[114]," size=",game.views[0].viewport.size)
	game.queue_free();await process_frame;quit()
