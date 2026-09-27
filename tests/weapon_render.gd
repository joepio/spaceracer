extends SceneTree
## Fixed three-view combat showcase; uses shipping models, HUD and post effects.
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	if "--players=3" in OS.get_cmdline_user_args():
		game.human_count=3;game.start_local()
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
	missile.velocity=frame.basis.z*600.;missile.terminal=.3;missile.age=2.
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
	if "--pickup-showcase" in OS.get_cmdline_user_args():
		race.weapons.missiles.clear();race.weapons.shots.clear()
		var pickup:Dictionary=race.weapons.pickups[1]
		for i in range(race.racers.size()):
			var p:Dictionary=race.racers[i]
			p.distance=pickup.distance+[3.,-40.,-75.,400.,500.,600.][i]
			p.warp_time=0.;p.warp_fx=0.;p.drone_time=0.;p.missile_warning=0.;p.shield_hit=0.;p.speed=180.
		var collector:Dictionary=race.racers[0]
		collector.weapon="";collector.weapon_before=pickup.distance-4.;collector.weapon_x_before=pickup.x;collector.x=pickup.x
		race.weapons.collect(race,collector)
		if "--pickup-respawn" in OS.get_cmdline_user_args(): race.weapons.begin_step(race,2.2,[{},{},{},{},{},{}])
	if "--bump-showcase" in OS.get_cmdline_user_args():
		race.weapons.missiles.clear();race.weapons.shots.clear()
		for i in range(race.racers.size()):
			var p:Dictionary=race.racers[i]
			p.distance=start+[0.,0.,-40.,400.,500.,600.][i]
			p.x=-4. if i==0 else 4. if i==1 else 0.
			p.warp_time=0.;p.warp_fx=0.;p.drone_time=0.;p.missile_warning=0.;p.shield_hit=0.;p.speed=200.
		race.Bump.begin(race.racers[0],{"right":true},.01,0.)
		race.racers[0].bump_time=.12
		race.resolve_contacts()
		assert(race.racers[1].energy==86.)
	if "--battery-showcase" in OS.get_cmdline_user_args():
		race.weapons.missiles.clear();race.weapons.shots.clear()
		var battery:Dictionary=race.weapons.batteries[1]
		for i in range(race.racers.size()):
			var p:Dictionary=race.racers[i]
			p.distance=battery.distance+[3.,-18.,-45.,400.,500.,600.][i];p.x=0.
			p.warp_time=0.;p.warp_fx=0.;p.drone_time=0.;p.missile_warning=0.;p.shield_hit=0.;p.speed=180.
		var collector:Dictionary=race.racers[0]
		collector.energy=35.;collector.weapon="missile"
		collector.weapon_before=battery.distance-4.;collector.weapon_x_before=battery.x;collector.x=battery.x
		race.weapons.collect_energy(race,collector)
		assert(collector.energy==60. and collector.weapon=="missile")
		if "--pickup-respawn" in OS.get_cmdline_user_args(): race.weapons.begin_step(race,2.2,[{},{},{},{},{},{}])
	if "--missile-showcase" in OS.get_cmdline_user_args():
		race.racers[1].warp_time=0.;race.racers[1].warp_fx=0.;race.racers[2].drone_time=0.;race.weapons.shots.clear()
		var blast_frame:Transform3D=race.Weapons.pose(race,race.racers[2])
		var blast_age:=.95 if "--smoke-tail" in OS.get_cmdline_user_args() else .22
		race.weapons.bursts.append({"id":999,"position":blast_frame.origin+blast_frame.basis*Vector3(12,3,25),"life":race.Weapons.MISSILE_BLAST_LIFE-blast_age})
		for j in range(16): missile.trail.append(missile.position-frame.basis.z*(15.+j*9.))
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
	if "--emp-showcase" in OS.get_cmdline_user_args():
		for view in game.views:
			var powered:bool=race.racers[view.index].emp_time<=0.
			assert(view.visor.systems_online==powered)
			assert(is_equal_approx(view.visor.projection.get_shader_parameter("online"),1. if powered else 0.))
			assert(view.visor.surface.render_target_update_mode==(SubViewport.UPDATE_ALWAYS if powered else SubViewport.UPDATE_DISABLED))
		print("EMP_VISOR blackout and emitter immunity verified")
	if "--pickup-showcase" in OS.get_cmdline_user_args():
		var respawn:bool="--pickup-respawn" in OS.get_cmdline_user_args()
		assert(game.world.weapon_vfx.pickup_bases[1].visible==respawn)
		assert(game.world.weapon_vfx.pickup_lights[0].visible!=respawn)
		assert(game.world.weapon_vfx.pickup_halos[0].visible!=respawn)
		print("PICKUP_RENDER respawn=",respawn," collected=",race.racers[0].weapon)
	if "--bump-showcase" in OS.get_cmdline_user_args():
		assert(game.world.weapon_vfx.bump_jets[0].visible and not game.world.weapon_vfx.bump_jets[1].visible)
		assert(game.world.weapon_vfx.shields[1].visible)
		print("BUMP_RENDER contact damage and opposing thruster verified")
	if "--battery-showcase" in OS.get_cmdline_user_args():
		var respawn:bool="--pickup-respawn" in OS.get_cmdline_user_args()
		assert(game.world.weapon_vfx.battery_batches[0].get_instance_transform(1).basis.determinant()>0. if respawn else game.world.weapon_vfx.battery_batches[0].get_instance_transform(1).basis.determinant()==0.)
		assert(game.world.weapon_vfx.pickup_lights[0].visible!=respawn)
		print("BATTERY_RENDER respawn=",respawn," energy=",race.racers[0].energy)
	if "--missile-showcase" in OS.get_cmdline_user_args():
		assert(game.world.weapon_vfx.smoke.visible_instance_count==16)
		assert(game.world.weapon_vfx.explosions[0].layers.size()==4)
		assert(game.world.weapon_vfx.blast_lights[0].visible==not ("--smoke-tail" in OS.get_cmdline_user_args()))
		print("MISSILE_RENDER bounded smoke and flash verified")
	var output:="C:/dev/ion-rush-captures/controls/weapons-showcase.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	root.get_texture().get_image().save_png(output)
	if "--emp-showcase" in OS.get_cmdline_user_args():
		for p in race.racers: p.emp_time=0.
		for view in game.views:
			view.visor._process(.1)
			assert(view.visor.brightness>0. and view.visor.brightness<=1.)
			view.visor._process(.2)
			assert(view.visor.systems_online and view.visor.brightness==1.)
		print("EMP_VISOR reboot verified")
	print("WEAPON_RENDER views=",game.views.size()," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	gpu.sort();cpu.sort();frames.sort()
	print("WEAPON_BENCH ",JSON.stringify({"gpu_ms":gpu[90],"cpu_ms":cpu[90],"median_ms":frames[90],"p95_ms":frames[171],"viewport_size":str(game.views[0].viewport.size)}))
	game.queue_free()
	for i in range(3): await process_frame
	quit()
