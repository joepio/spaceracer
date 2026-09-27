extends SceneTree
const Race=preload("res://src/race.gd")
const Air=preload("res://src/air_batteries.gd")
const Obstacles=preload("res://src/obstacles.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func airborne_cross(race:RefCounted,p:Dictionary,b:Dictionary,offset:float=0.)->void:
	p.airborne=true;p.weapon_was_airborne=true
	p.weapon_position_before=b.pose*Vector3(offset,0.,-20.)
	p.air_position=b.pose*Vector3(offset,0.,20.)
	race.weapons.collect_energy(race,p)
func run()->void:
	for biome in ["city","forest","cell"]:
		for difficulty in ["easy","normal","hard"]:
			for seed_value in [6,31,145,421]:
				var race:=Race.new([{"slot":0}],seed_value,3,difficulty,biome)
				var items:Array=race.weapons.batteries.filter(func(b):return b.get("air",false))
				check(items.size()>0 and items.size()<=4,"Sparse air pickups exist: %s %s %s"%[biome,difficulty,seed_value])
				var repeated:Array[Dictionary]=[]
				for item in race.weapons.batteries:
					if not item.get("air",false): repeated.append(item.duplicate(true))
				Air.generate(race.track,repeated)
				repeated.assign(repeated.filter(func(item):return item.get("air",false)))
				check(items==repeated,"Air pickups reproduce from seed")
				for b in items:
					var n:Dictionary=race.track.sample(b.distance)
					var height:float=(b.pose.origin-n.p).dot(n.frame.y)
					check(height>=15. and height<=35. and absf(b.x)>n.width*.5,"Air pickups require elevation and lateral detour")
	var race:=Race.new([{"slot":2},{"slot":7}],31)
	race.countdown=0.;race.clock=5.
	var b:Dictionary=race.weapons.batteries.filter(func(item):return item.get("air",false))[0]
	var p:Dictionary=race.racers[0]
	p.energy=40.;p.weapon="missile";p.weapon_before=b.distance;p.distance=b.distance
	for state in ["grounded","crashed","recovery","warp_time"]:
		p.airborne=state!="grounded";p.weapon_was_airborne=true
		p.weapon_position_before=b.pose*Vector3(0.,0.,-20.);p.air_position=b.pose*Vector3(0.,0.,20.)
		if state!="grounded": p[state]=true if state=="crashed" else 1.
		race.weapons.collect_energy(race,p)
		check(p.energy==40. and b.cooldown==0.,"Cannot collect aerial battery while "+state)
		if state!="grounded": p[state]=false if state=="crashed" else 0.
	airborne_cross(race,p,b,10.)
	check(p.energy==40.,"Missing the physical battery cannot collect via track progress")
	airborne_cross(race,p,b)
	check(p.energy==65. and p.weapon=="missile" and b.cooldown==2. and p.pickup_energy,"Fast swept flight collects energy with shared visual feedback")
	race.weapons.begin_step(race,2.1,[{},{}]);airborne_cross(race,p,b)
	check(p.energy==65.,"Circling in the air cannot farm the same pickup per lap")
	p.lap=2;airborne_cross(race,p,b)
	check(p.energy==90.,"Air battery can be collected next lap")
	race.weapons.begin_step(race,2.1,[{},{}]);p.lap=3
	p.weapon_position_before=b.pose*Vector3(0.,0.,-300.);p.air_position=b.pose.origin
	race.weapons.collect_energy(race,p)
	check(p.energy==90.,"Teleporting through a battery cannot collect it")
	p.energy=100.;airborne_cross(race,p,b)
	check(b.cooldown==0.,"Full battery leaves pickup available")
	p.energy=90.;airborne_cross(race,p,b)
	check(p.energy==100. and p.energy_gained==10.,"Aerial refill caps at 100")
	# Real airborne physics snapshots must reach collection through end_step.
	race.weapons.begin_step(race,2.1,[{},{}]);p.lap=4;p.energy=40.
	p.air_position=b.pose*Vector3(0.,0.,-2.);p.air_frame=b.pose.basis
	p.air_velocity=b.pose.basis.z*220.;p.air_entry_speed=220.;p.air_time=1.;p.distance=b.distance
	race.step(.025,[{"throttle":1.},{}])
	check(p.energy==65. and not p.crashed,"Live flight collects airborne pickup without grounded progress")
	race.track.obstacles=Obstacles.new()
	race.track.obstacles.add_box(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*12.),b.pose.origin))
	Air.validate(race.track,race.weapons.batteries)
	check(not race.weapons.batteries.has(b),"Air pickups inside solid scenery are omitted")
	if "--render" in OS.get_cmdline_user_args(): await render_scene()
	print("AIR_BATTERY_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
func render_scene()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game)
	game.human_count=1;game.next_seed=31
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): game.next_seed=int(arg.trim_prefix("--seed="))
	game.start_local()
	game.set_process(false);game.set_physics_process(false)
	game.race.countdown=0.;game.race.clock=12.
	var items:Array=game.race.weapons.batteries.filter(func(b):return b.get("air",false))
	check(not items.is_empty(),"Playable airborne detours remain after scenery validation")
	if items.is_empty(): game.queue_free();await process_frame;return
	for item in items: check(Air.route_clear(game.race.track,item),"Native scenery leaves approach and exit clear")
	var battery:Dictionary=items[0]
	for i in range(game.race.racers.size()):
		var pilot:Dictionary=game.race.racers[i]
		pilot.distance=battery.distance-75.+i*500.;pilot.x=0.;pilot.speed=265.;pilot.startup=1.;pilot.engine_power=1.;pilot.thrust=1.
	game.world.update_ships()
	game.world.update_camera(game.views[0].camera,0,0.,true)
	game.views[0].hud.visible=true;game.views[0].hud.queue_redraw()
	for frame in range(30): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/air-battery-"+game.race.track.biome+".png")
	var collector:Dictionary=game.race.racers[0];collector.energy=40.
	collector.weapon_before=battery.distance;collector.distance=battery.distance
	airborne_cross(game.race,collector,battery);game.world.update_ships()
	var index:int=game.race.weapons.batteries.find(battery)
	check(game.world.weapon_vfx.battery_batches[0].get_instance_transform(index).basis.determinant()==0.,"Collected airborne battery disappears from shared instanced mesh")
	check(game.world.weapon_vfx.pickup_lights[0].visible and game.world.weapon_vfx.pickup_halos[0].visible,"Aerial collection illuminates the collector")
	game.race.weapons.begin_step(game.race,2.1,[{},{},{},{},{},{}]);game.world.update_ships()
	check(game.world.weapon_vfx.battery_batches[0].get_instance_transform(index).basis.determinant()>1.,"Airborne battery respawns at its larger visible scale")
	print("AIR_BATTERY_RENDER ",game.race.track.biome," detours=",items.size())
	game.queue_free();await process_frame
