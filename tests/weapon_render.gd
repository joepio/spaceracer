extends SceneTree
## Fixed three-view combat showcase; uses shipping models, HUD and post effects.
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	var race:RefCounted=game.race
	race.countdown=0.;race.clock=12.;race.vfx_clock=12.
	var start:float=race.weapons.pickups[1].distance-70.
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		p.distance=start+[100.,40.,0.,60.,-50.,-90.][i]
		p.x=0.;p.speed=265.;p.startup=1.;p.ignited=true;p.engine_power=1.;p.input_throttle=1.;p.thrust=1.
	race.racers[4].weapon="missile";race.weapons.activate(race,4)
	var missile:Dictionary=race.weapons.missiles[0]
	var frame:Transform3D=race.Weapons.pose(race,race.racers[0])
	missile.position=frame.origin+frame.basis*Vector3(12,7,-9)
	missile.velocity=frame.basis.z*600.;missile.terminal=.3
	race.racers[0].missile_warning=2.;race.racers[0].energy=62.;race.racers[0].shield_hit=.16
	race.racers[1].warp_time=1.8;race.racers[1].warp_fx=1.;race.racers[1].warp_age=1.;race.racers[1].speed=510.
	race.racers[2].drone_time=6.5;race.racers[2].drone_target=3
	race.weapons.shots.append({"from":race.Weapons.drone_position(race,race.racers[2]),"to":race.Weapons.pose(race,race.racers[3]).origin,"life":.1})
	if "--emp-showcase" in OS.get_cmdline_user_args():
		race.weapons.missiles.clear();race.weapons.shots.clear()
		for i in range(race.racers.size()):
			var p:Dictionary=race.racers[i]
			p.distance=start+[0.,65.,-75.,400.,500.,600.][i]
			p.warp_time=0.;p.warp_fx=0.;p.drone_time=0.;p.missile_warning=0.;p.shield_hit=0.;p.speed=240.
		race.racers[0].weapon="emp";race.weapons.activate(race,0)
		race.weapons.step_emp(race,.3)
	if "--jammer-showcase" in OS.get_cmdline_user_args():
		race.weapons.missiles.clear();race.weapons.shots.clear()
		for i in range(race.racers.size()):
			var p:Dictionary=race.racers[i]
			p.distance=start+[0.,50.,155.,400.,500.,600.][i]
			p.warp_time=0.;p.warp_fx=0.;p.drone_time=0.;p.missile_warning=0.;p.shield_hit=0.;p.speed=240.
		race.racers[0].weapon="jammer";race.weapons.activate(race,0)
		race.racers[0].jammer_deploy=1.
		race.weapons.step_jammers(race)
	for view in game.views: game.world.update_camera(view.camera,view.index,0.,true)
	for view in game.views: RenderingServer.viewport_set_measure_render_time(view.viewport.get_viewport_rid(),true)
	var gpu:Array[float]=[]
	var cpu:Array[float]=[]
	var frames:Array[float]=[]
	var last:=Time.get_ticks_usec()
	for i in range(240):
		game.world.update_ships()
		for view in game.views:
			game.update_speed_effects(view,1./120.)
			view.hud.visible=true;view.hud.queue_redraw()
		await process_frame
		var now:=Time.get_ticks_usec()
		if i>=60:
			var sum_gpu:=0.;var sum_cpu:=0.
			for view in game.views:
				sum_gpu+=RenderingServer.viewport_get_measured_render_time_gpu(view.viewport.get_viewport_rid())
				sum_cpu+=RenderingServer.viewport_get_measured_render_time_cpu(view.viewport.get_viewport_rid())
			gpu.append(sum_gpu);cpu.append(sum_cpu);frames.append((now-last)/1000.)
		last=now
	await RenderingServer.frame_post_draw
	var output:="C:/dev/ion-rush-captures/controls/weapons-showcase.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	root.get_texture().get_image().save_png(output)
	print("WEAPON_RENDER views=",game.views.size()," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	gpu.sort();cpu.sort();frames.sort()
	print("WEAPON_BENCH ",JSON.stringify({"gpu_ms":gpu[90],"cpu_ms":cpu[90],"median_ms":frames[90],"p95_ms":frames[171],"viewport_size":str(game.views[0].viewport.size)}))
	game.queue_free()
	for i in range(3): await process_frame
	quit()
