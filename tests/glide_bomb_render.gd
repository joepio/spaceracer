extends SceneTree
const Bomb=preload("res://src/dive_bomb.gd")
func _initialize()->void:
	root.unfocusable=true;call_deferred("run")
func capture(name_value:String)->void:
	for frame in range(16): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/"+name_value+".png")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.human_count=2;game.biome="city";game.next_seed=31;game.start_local()
	game.running=false;game.set_process(false);game.set_physics_process(false)
	var race:RefCounted=game.race
	race.countdown=0.;race.clock=20.;race.vfx_clock=20.
	var p:Dictionary=race.racers[0]
	p.weapon="bomb";p.airborne=true;p.startup=1.;p.engine_power=1.
	var aim:Dictionary={}
	for distance in range(400,2200,80):
		var n:Dictionary=race.track.sample(distance)
		p.distance=distance;p.air_position=race.Track.point(n,0.,100.);p.air_frame=n.frame*Basis(Vector3.RIGHT,.35)
		p.air_velocity=p.air_frame.z*240.;p.speed=240.
		aim=Bomb.preview(race,p)
		if aim.landed and aim.normal.dot(Vector3.UP)>.5: break
	var target:Dictionary=race.racers[2]
	target.airborne=true;target.air_position=aim.position+aim.normal*4.+p.air_frame.x*22.;target.air_velocity=Vector3.ZERO
	target.air_frame=p.air_frame;target.weapon_guard=0.;target.startup=1.
	var p2:Dictionary=race.racers[1]
	p2.airborne=true;p2.air_position=p.air_position-p.air_frame.z*30.;p2.air_frame=p.air_frame;p2.air_velocity=p.air_velocity
	p2.distance=p.distance;p2.weapon="bomb";p2.startup=1.
	var timings:Array[int]=[]
	for i in range(12):
		var start:=Time.get_ticks_usec();Bomb.preview(race,p);timings.append(Time.get_ticks_usec()-start)
	timings.sort();print("GLIDE_PREVIEW_US median=",timings[6]," max=",timings[-1])
	var start:=Time.get_ticks_usec()
	for i in range(24): Bomb.acquire(race,p,Bomb.launch_state(race,p))
	print("GLIDE_ACQUIRE_US ",(Time.get_ticks_usec()-start)/24.)
	start=Time.get_ticks_usec()
	for i in range(120): Bomb.contact(race.track,p.air_position,p.air_position+p.air_velocity*.12,p.distance,true)
	print("GLIDE_CONTACT_US ",(Time.get_ticks_usec()-start)/120.)
	var batch_times:Array[int]=[]
	for tick in range(30):
		start=Time.get_ticks_usec()
		for slot in range(4):
			p.air_position+=p.air_frame.x*.05
			Bomb.preview(race,p)
		batch_times.append(Time.get_ticks_usec()-start)
	batch_times.sort()
	print("GLIDE_FOUR_PREVIEWS_US median=",batch_times[15]," p95=",batch_times[28])
	for pilot in [p,p2]:
		pilot.bomb_armed=true;pilot.bomb_preview=Bomb.preview(race,pilot)
		print("GLIDE_PREVIEW landed=",pilot.bomb_preview.landed," target=",pilot.bomb_preview.target," time=",pilot.bomb_preview.time)
	game.world.update_ships()
	for view in game.views:
		game.world.update_camera(view.camera,view.index,0.,true);view.hud.queue_redraw()
	await capture("glide-bomb-aim-split")
	# Road targets were the worst case: each old prediction repeatedly sampled
	# future road frames inside its collision/steering loop.
	var old_target:Dictionary=target.duplicate(true)
	var projected:Dictionary=race.track.project(target.air_position,p.distance,race.track.length)
	target.airborne=false;target.distance=projected.distance;target.x=0.;target.speed=190.;target.ground_velocity=projected.node.frame.z*190.
	for mode in ["road_lock","no_lock"]:
		if mode=="no_lock":
			for rival in race.racers:
				if rival!=p: rival.warp_time=1.
		timings.clear()
		for tick in range(30):
			start=Time.get_ticks_usec();var measured:=Bomb.preview(race,p)
			timings.append(Time.get_ticks_usec()-start)
			if tick==0: print("GLIDE_MODE ",mode," target=",measured.target)
		timings.sort();print("GLIDE_",mode.to_upper(),"_US median=",timings[15]," p95=",timings[28])
	target.merge(old_target,true)
	for rival in race.racers: rival.warp_time=0.
	p.destruction_notices=[{"name":"FLUX","life":.4}]
	for view in game.views: view.hud.queue_redraw()
	await capture("destruction-confirmation-split")
	race.weapons.activate(race,0);p.bomb_armed=false
	var bomb:Dictionary=race.weapons.bombs[0]
	for i in range(30): Bomb.step(race.weapons,race,bomb,1./60.)
	game.world.update_ships()
	var camera:Camera3D=game.views[0].camera
	camera.position=bomb.position-bomb.velocity.normalized()*12.+Vector3(7,5,0)
	camera.look_at(bomb.position,Vector3.UP);camera.fov=48.
	for view in game.views: view.hud.queue_redraw()
	await capture("glide-bomb-wings")
	game.queue_free();await process_frame;quit()
