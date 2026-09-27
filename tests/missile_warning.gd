extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game)
	game.human_count=2;game.next_seed=31;game.start_local()
	game.set_process(false);game.set_physics_process(false)
	var race:RefCounted=game.race
	race.countdown=0.;race.clock=20.;race.vfx_clock=20.
	var start:float=race.track.length*.055
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		p.distance=start-i*22.;p.x=0.;p.speed=220.;p.startup=1.;p.engine_power=1.
		race.racers[i].ground_velocity=race.track.sample(p.distance).frame.z*220.
	race.racers[2].weapon="missile";race.weapons.activate(race,2)
	var missile:Dictionary=race.weapons.missiles[0]
	var output:="C:/dev/ion-rush-captures/missile-warning"
	DirAccess.make_dir_recursive_absolute(output)
	var brightness:=0.
	for eta in [4.,1.5,.2]:
		missile.distance=start-eta*(race.Weapons.MISSILE_SPEED-220.)
		missile.position=race.Track.point(race.track.sample(missile.distance),0.,10.)
		# Offset the close approach so the beam profile is visible beside the hull.
		if eta<1.: missile.position+=race.track.sample(missile.distance).frame.x*18.
		missile.terminal=-1.
		check(is_equal_approx(race.Weapons.missile_eta(race,missile),eta),"Cruise warning accounts for target speed and route distance")
		game.world.update_ships()
		var beam:MeshInstance3D=game.world.weapon_vfx.missile_nodes[missile.id].get_meta("laser")
		check(beam.visible==(eta<2.),"Laser appears only inside the two-second impact window")
		var effects:Node3D=game.world.weapon_vfx.missile_nodes[missile.id]
		check(effects.get_meta("contact").visible==beam.visible and effects.get_meta("contact_light").visible==beam.visible,"Contact glow and hull light share warning timing")
		if eta<2.:
			var energy:float=beam.material_override.get_shader_parameter("strength")
			check(energy>brightness,"Laser brightness increases as impact approaches")
			brightness=energy
		for view in game.views:
			game.world.update_camera(view.camera,view.index,0.,true)
			view.hud.queue_redraw()
		for frame in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("eta-%.1f.png"%eta))
	missile.disabled=true;missile.evaded=true;game.world.update_ships()
	check(not game.world.weapon_vfx.missile_nodes[missile.id].get_meta("engine").visible,"EMP extinguishes missile exhaust")
	check(not game.world.weapon_vfx.missile_nodes[missile.id].get_meta("laser").visible,"EMP removes targeting laser")
	check(not game.world.weapon_vfx.missile_nodes[missile.id].get_meta("contact").visible and not game.world.weapon_vfx.missile_nodes[missile.id].get_meta("contact_light").visible,"EMP removes contact glow and hull light")
	missile.disabled=false;missile.evaded=true;game.world.update_ships()
	check(not game.world.weapon_vfx.missile_nodes[missile.id].get_meta("laser").visible,"Successful evasion immediately removes the laser")
	game.queue_free();await process_frame
	print("MISSILE_WARNING_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
