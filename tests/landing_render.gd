extends SceneTree
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	var race:RefCounted=game.race
	race.countdown=0.;race.clock=12.;race.vfx_clock=12.
	var p:Dictionary=race.racers[0]
	p.distance=race.track.jumps[0].landing+25.;p.x=0.;p.speed=200.;p.startup=1.;p.ignited=true
	p.engine_power=1.;p.input_throttle=1.;p.thrust=1.;p.airborne=true;p.air_time=.6;p.air_travel=0.
	p.weapon="landing"
	var n:Dictionary=race.track.sample(p.distance)
	p.air_position=race.Track.point(n,0.,13.3);p.air_frame=n.frame*Basis(Vector3.BACK,.65)
	p.air_velocity=n.frame.z*200.-n.frame.y*65.
	race.Flight.step(p,race.track,.03,0.,0.,1.,0.)
	for view in game.views: game.world.update_camera(view.camera,view.index,0.,true)
	for tick in range(60):
		game.world.update_ships()
		for view in game.views:
			view.hud.visible=true;view.hud.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	var output:="C:/dev/ion-rush-captures/controls/landing-assist.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	root.get_texture().get_image().save_png(output)
	print("LANDING_RENDER active=",p.landing_assist>0.," jets=",game.world.weapon_vfx.guidance[0].visible)
	game.queue_free()
	for i in range(3): await process_frame
	quit()
