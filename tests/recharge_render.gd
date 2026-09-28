extends SceneTree
func _initialize()->void: root.unfocusable=true;call_deferred("run")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	for biome in ["city","forest","cell"]:
		game.human_count=2;game.biome=biome;game.difficulty="hard";game.next_seed=31;game.start_local()
		game.set_process(false);game.set_physics_process(false);game.running=false
		var race:RefCounted=game.race;race.countdown=0.;race.clock=20.;race.vfx_clock=20.
		var strip:Dictionary=race.track.recharge_strips[0]
		for i in range(race.racers.size()):
			var p:Dictionary=race.racers[i]
			p.distance=strip.start+50.+i*30.;p.x=race.track.sample(p.distance).width*-.29
			p.energy=25.;p.speed=180.;p.startup=1.;p.engine_power=.8
			race.Track.Recharge.apply(p,race.track.sample(p.distance),.5)
		game.world.update_ships()
		for view in game.views:
			game.world.update_camera(view.camera,view.index,0.,true);view.hud.queue_redraw()
		for i in range(20): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/recharge-"+biome+".png")
		print("RECHARGE_RENDER ",biome," players=",race.racers[0].energy,",",race.racers[1].energy)
	game.queue_free();await process_frame;quit()
