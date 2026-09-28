extends SceneTree
func _initialize()->void:
	root.unfocusable=true;call_deferred("run")
func capture(name_value:String)->void:
	for frame in range(18): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/"+name_value+".png")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.human_count=2;game.biome="city";game.next_seed=31;game.start_local()
	game.set_process(false);game.set_physics_process(false);game.running=true;game.in_menu=false
	var race:RefCounted=game.race
	race.countdown=0.;race.clock=20.;race.vfx_clock=20.
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		p.distance=600.+i*25.;p.x=0.;p.speed=265.;p.startup=1.;p.engine_power=1.
	race.racers[0].weapon="missile";race.weapons.activate(race,0)
	var m:Dictionary=race.weapons.missiles[0];var n:Dictionary=race.track.sample(1000.)
	m.position=race.Track.point(n,0.,100.);m.age=2.;m.distance=1000.;m.velocity=n.frame.z*400.
	for i in range(48): m.trail.append(m.position-n.frame.z*(i*6.))
	game.world.update_ships()
	var camera:Camera3D=game.views[0].camera
	camera.position=m.trail[20]+n.frame.x*35.+n.frame.y*7.;camera.look_at(m.trail[20],n.frame.y);camera.fov=65.
	game.views[1].camera.position=m.trail[20]+n.frame.x*.5
	game.views[1].camera.look_at(m.trail[8],n.frame.y);game.views[1].camera.fov=75.
	for view in game.views: view.hud.visible=false
	await capture("smoke-side-and-inside")
	race.weapons.missiles.clear();race.racers[0].weapon="emp";race.weapons.activate(race,0);race.weapons.step_emp(race,.01)
	for age in [.1,.3,.55]:
		race.racers[1].emp_time=race.Weapons.EMP_DURATION-age;race.vfx_clock=20.+age
		game.world.update_ships()
		for view in game.views:
			view.hud.visible=true;game.world.update_camera(view.camera,view.index,0.,true)
			game.update_speed_effects(view,0.);view.hud.queue_redraw()
		await capture("emp-glitch-%.2f"%age)
		print("EMP_VISUAL age=",age," glitch=",game.views[1].blur.get_shader_parameter("jam")," hud=",game.views[1].visor.projection.get_shader_parameter("online"))
	game.queue_free();await process_frame;quit()
