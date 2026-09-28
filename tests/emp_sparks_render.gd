extends SceneTree
var game:Node
var output:="C:/dev/ion-rush-captures/gi/emp-sparks"
func _initialize()->void:
	root.unfocusable=true;DirAccess.make_dir_recursive_absolute(output);call_deferred("run")
func capture(label:String)->void:
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func run()->void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.human_count=1;game.biome="city";game.next_seed=31;game.start_local()
	game.set_process(false);game.set_physics_process(false);game.running=false
	var race:RefCounted=game.race
	race.countdown=0.;race.clock=20.;race.vfx_clock=20.
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i];p.distance=600.+i*70.;p.startup=1.;p.speed=170.;p.engine_power=0.;p.thrust=0.
	var target:Dictionary=race.racers[0]
	var camera:Camera3D=game.views[0].camera
	game.views[0].hud.visible=false
	for age in [.12,.68,1.4,2.05]:
		target.emp_time=race.Weapons.EMP_DURATION-age;game.world.update_ships()
		var frame:Transform3D=race.Weapons.pose(race,target)
		camera.position=frame*Vector3(10,8,-13);camera.look_at(frame*Vector3(0,.5,-.5),frame.basis.y);camera.fov=48.
		await capture("close-%.2f"%age)
		assert(game.world.weapon_vfx.emp_arcs[0].visible)
		assert(not game.world.weapon_vfx.emp_arcs[1].visible)
		assert(game.world.weapon_vfx.emp_arcs[0].mesh is ArrayMesh)
		assert(game.world.weapon_vfx.emp_arcs[0].transform.is_equal_approx(frame))
		if age==1.4:
			game.world.update_camera(camera,0,0.,true);await capture("chase")
	target.emp_time=0.;game.world.update_ships()
	assert(not game.world.weapon_vfx.emp_arcs[0].visible)
	target.emp_time=1.;target.crashed=true;game.world.update_ships()
	assert(not game.world.weapon_vfx.emp_arcs[0].visible)
	print("EMP_SPARKS_RENDER attached arcs, unaffected rivals, recovery and crash cleanup verified")
	game.queue_free();await process_frame;quit()
