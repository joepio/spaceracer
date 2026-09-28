extends SceneTree
func _initialize()->void:
	root.unfocusable=true;call_deferred("run")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.human_count=1;game.biome="city";game.next_seed=31;game.start_local()
	game.running=false;game.set_process(false);game.set_physics_process(false)
	game.race.countdown=0.;game.race.clock=20.;game.race.vfx_clock=20.
	var track:RefCounted=game.race.track
	var n:Dictionary=track.sample(600.)
	for i in range(game.race.racers.size()):
		var p:Dictionary=game.race.racers[i]
		p.distance=600.+i*25.;p.x=-12.+i*5.;p.speed=200.;p.startup=1.;p.weapon="bomb"
	game.world.update_ships()
	var camera:Camera3D=game.views[0].camera
	camera.global_position=track.point(n,-35.,23.)-n.frame.z*23.
	camera.look_at(track.point(n,0.,2.),n.frame.y)
	for view in game.views: view.hud.visible=false
	for frame in range(35): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/missile-trail-before.png")
	game.race.checkpoints.gates.clear()
	for p in game.race.racers: p.distance=2200.+p.slot*30.;p.weapon=""
	game.race.racers[1].distance=180.;game.race.racers[1].weapon="missile"
	game.race.weapons.activate(game.race,1)
	var missile:Dictionary=game.race.weapons.missiles[0]
	for i in range(140): game.race.weapons.step_missile(game.race,missile,1./120.)
	var frame:Dictionary=track.sample(missile.distance-100.)
	camera.global_position=track.point(frame,-80.,65.)-frame.frame.z*30.
	camera.look_at(missile.position-frame.frame.z*65.)
	game.world.update_ships()
	for i in range(25): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/missile-trail.png")
	game.queue_free();await process_frame;quit()
