extends SceneTree
func _initialize()->void: root.unfocusable=true;call_deferred("run")
func capture(stage:String)->void:
	for frame in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/respawn-"+stage+".png")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.human_count=1;game.biome="city";game.next_seed=31;game.start_local()
	game.running=false;game.set_process(false);game.set_physics_process(false)
	var race:RefCounted=game.race;race.countdown=0.;race.clock=20.;race.vfx_clock=20.
	var p:Dictionary=race.racers[0];p.distance=740.;p.color="#bf3334";p.startup=1.
	var n:Dictionary=race.track.sample(p.distance)
	p.airborne=true;p.air_frame=n.frame;p.air_position=race.Track.point(n,65.,40.);p.air_velocity=n.frame.z*210.;p.speed=210.
	game.world.update_ships();game.world.update_camera(game.views[0].camera,0,0.,true)
	race.Flight.crash(p);game.world.update_ships()
	var input:Array=[]
	for pilot in race.racers: input.append({})
	var ticks:={1:"impact",84:"travel",212:"destination",257:"scan-start",284:"scan-top",335:"complete"}
	for tick in range(1,336):
		race.step(1./120.,input);game.world.update_ships()
		game.world.update_camera(game.views[0].camera,0,1./120.)
		game.views[0].hud.queue_redraw()
		if ticks.has(tick): await capture(ticks[tick])
	print("RESPAWN_RENDER complete")
	game.queue_free();await process_frame;quit()
