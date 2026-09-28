extends SceneTree
func _initialize()->void:
	root.unfocusable=true;call_deferred("run")
func capture(name_value:String)->void:
	for frame in range(16): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/"+name_value+".png")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.human_count=1;game.next_seed=33;game.difficulty="hard";game.biome="city";game.start_local()
	game.running=false;game.set_process(false);game.set_physics_process(false)
	game.race.countdown=0.;game.race.clock=20.;game.race.vfx_clock=20.
	for view in game.views: view.hud.visible=false
	var camera:Camera3D=game.views[0].camera
	var markers:Array=game.world.get_meta("turn_markers")
	for level in [1,2,3]:
		var choices:Array=markers.filter(func(m):return m.level==level and (level!=3 or m.exposed))
		if choices.is_empty(): continue
		var sign_info:Dictionary=choices[0]
		var frame:Transform3D=sign_info.frame
		camera.position=frame*Vector3(3.,1.5,32.);camera.look_at(frame*Vector3(0,-.6,0),frame.basis.y);camera.fov=42.
		game.world.update_ships()
		await capture("corner-warning-"+str(level))
		if level==3:
			game.race.vfx_clock+=.14;game.world.update_ships();await capture("corner-warning-red-sweep")
			var p:Dictionary=game.race.racers[0];p.distance=sign_info.distance-55.;p.x=0.;p.speed=260.;p.startup=1.;p.engine_power=1.
			game.world.update_ships();game.world.update_camera(camera,0,0.,true)
			await capture("corner-warning-approach")
	game.queue_free();await process_frame;quit()
