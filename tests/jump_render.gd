extends SceneTree
var game:Node
var output:="C:/dev/ion-rush-captures/flight-difficulty"
func _initialize()->void:
	root.unfocusable=true
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func shot(label:String)->void:
	game.world.update_ships()
	for view in game.views:
		game.world.update_camera(view.camera,view.index,0.,true)
		view.hud.queue_redraw()
	for frame in range(60): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
	print("JUMP_CAPTURE ",label)
func run()->void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false);game.set_physics_process(false)
	await shot("menu")
	game.difficulty="hard";game.next_seed=31;game.human_count=1;game.start_local()
	game.running=false;game.race.countdown=0.;game.race.clock=20.
	for jump in game.race.track.jumps:
		for p in game.race.racers:
			p.distance=jump.takeoff-85.-p.slot*20.;p.speed=250.;p.x=0.;p.heading=0.;p.slip=0.
			p.airborne=false;p.recovery=0.;p.lift=0.;p.lift_speed=0.;p.unload=0.;p.trim=0.
			p.startup=1.;p.engine_power=1.;p.thrust=1.;p.finished=false
		game.race.over=false
		await shot(jump.kind+"-approach")
		for tick in range(120*6):
			var inputs:Array=[]
			for p in game.race.racers: inputs.append(game.race.bot(p))
			game.race.step(1./120.,inputs)
			if game.race.racers[0].airborne and game.race.racers[0].air_time>.35: break
		await shot(jump.kind+"-airborne")
	game.queue_free()
	await process_frame
	quit()
