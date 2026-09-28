extends SceneTree
func _initialize()->void:
	root.unfocusable=true;call_deferred("run")
func capture(path:String)->void:
	for frame in range(15): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/"+path)
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.human_count=2;game.biome="city";game.next_seed=31;game.start_local()
	game.running=false;game.set_process(false);game.set_physics_process(false)
	game.race.countdown=0.;game.race.clock=20.;game.race.vfx_clock=20.
	var track:RefCounted=game.race.track
	var n:Dictionary=track.sample(600.)
	for i in range(game.race.racers.size()):
		var p:Dictionary=game.race.racers[i]
		p.distance=600.+i*25.;p.x=0.;p.speed=200.;p.startup=1.;p.weapon="railgun"
	game.race.racers[0].drone_time=4.2
	game.race.racers[1].drone_time=3.6;game.race.racers[1].weapon="bomb"
	game.world.update_ships()
	for view in game.views:
		view.camera.global_position=track.point(n,-8.,11.)-n.frame.z*22.
		view.camera.look_at(track.point(n,0.,2.)+n.frame.z*40.,n.frame.y)
		view.hud.queue_redraw()
	await capture("stored-items-split.png")
	game.race.racers[0].finished=true;game.race.racers[0].rank=1;game.race.racers[0].time=81.32
	game.views[0].hud.queue_redraw()
	await capture("winner-split.png")
	game.race.racers[0].finished=false;game.race.racers[0].drone_time=0.
	# A frozen action moment using the actual firing path, aligned above the road.
	var origin:Vector3=track.point(n,0.,5.)
	for i in range(2):
		var p:Dictionary=game.race.racers[i]
		p.airborne=true;p.air_frame=n.frame;p.air_position=origin+n.frame.z*(i*90.);p.energy=100.;p.weapon_guard=0.
	for view in game.views:
		view.camera.global_position=origin-n.frame.z*24.+n.frame.y*7.
		view.camera.look_at(origin+n.frame.z*50.,n.frame.y)
	game.race.racers[0].rail_view=game.race.Weapons.Railgun.view_context(game.race,0,game.views[0].camera)
	game.race.Weapons.Railgun.input_step(game.race.weapons,game.race,0,false,.016)
	game.world.update_ships()
	for view in game.views: view.hud.queue_redraw()
	await capture("railgun-aim-split.png")
	game.race.racers[0].rail_armed=false
	game.race.weapons.activate(game.race,0)
	game.race.weapons.rail_shots[0].life=.26
	game.race.racers[1].impact_age=.04
	game.world.update_ships()
	for view in game.views:
		view.camera.global_position=origin-n.frame.z*24.-n.frame.x*14.+n.frame.y*12.
		view.camera.look_at(origin+n.frame.z*40.,n.frame.y)
		view.hud.queue_redraw()
	await capture("railgun-shot.png")
	game.race.over=true
	game.race.racers[0].finished=true;game.race.racers[0].rank=1
	for view in game.views: view.hud.queue_redraw()
	await capture("winner-results-split.png")
	game.queue_free();await process_frame;quit()
