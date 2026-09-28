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
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/dive-bomb-mounted.png")
	var center:Vector3=track.point(track.sample(690.),0.,1.)
	game.race.weapons.bursts.append({"id":918,"position":center,"life":5.95,"duration":6.4,"size":45.})
	camera.global_position=track.point(n,-45.,32.)-n.frame.z*20.
	camera.look_at(center+Vector3.UP*10.)
	game.world.weapon_vfx.update()
	for frame in range(25): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/dive-bomb-blast.png")
	game.queue_free();await process_frame;quit()
