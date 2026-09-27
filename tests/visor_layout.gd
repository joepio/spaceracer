extends SceneTree
var game:Node
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func _initialize()->void:
	root.unfocusable=true;call_deferred("run")
func run()->void:
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	for example in [[1,"city"],[2,"city"],[4,"forest"]]:
		game.human_count=example[0];game.biome=example[1];game.next_seed=31;game.start_local()
		game.running=false;game.set_process(false);game.set_physics_process(false)
		game.race.countdown=0.;game.race.clock=20.;game.race.vfx_clock=20.
		for p in game.race.racers:
			p.distance=game.race.track.length*.05+p.slot*22.;p.speed=265.;p.startup=1.;p.engine_power=1.;p.thrust=1.
			p.weapon="missile";p.lap=2
		game.world.update_ships()
		for view in game.views:
			game.world.update_camera(view.camera,view.index,0.,true);view.hud.queue_redraw()
			var expected:float=.035 if example[0]==1 else .010
			check(is_equal_approx(view.visor.projection.get_shader_parameter("curvature"),expected),"Each visor uses its layout's curvature")
			check(view.hud.split_screen==(example[0]>1),"HUD knows the screen arrangement")
		if DisplayServer.get_name()!="headless":
			for frame in range(35): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/visor-layout-%d.png"%example[0])
	game.queue_free();await process_frame
	print("VISOR_LAYOUT_TESTS failures=",failures);quit(1 if failures else 0)
