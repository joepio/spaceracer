extends SceneTree
const Race=preload("res://src/race.gd")
const Flight=preload("res://src/flight.gd")
const Victory=preload("res://src/victory.gd")
var failures:=0
var checks:=0

func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)

func run()->void:
	var race:=Race.new([{"slot":0},{"slot":1}],31,1,"hard")
	race.countdown=0.
	var p:Dictionary=race.racers[0]
	p.distance=race.track.length-1.;p.speed=225.;p.startup=1.
	p.weapon="missile";p.drone_time=2.
	p.checkpoint_index=race.checkpoints.gates.size()
	race.step(.02,[{"throttle":1.},{}])
	check(p.finished and not race.over,"First finisher starts a victory lap while opponents race")
	check(p.weapon=="missile" and p.drone_time>0.,"Crossing the line does not clear held or active equipment")
	var finish_time:float=p.time
	var lap:int=p.lap
	var initial_distance:float=p.distance
	var start_pose:=Flight.pose(p,race.track.sample(p.distance),race.clock)
	var disruptive:={"throttle":0.,"brake":1.,"steer":1.,"strafe":-1.,"trim":-1.,"fire":true,"boost":true,"reset":true,"left":true}
	race.step(1./120.,[disruptive,{"throttle":1.}])
	check(p.victory_pose.origin.distance_to(start_pose.origin)<4.,"Victory handoff preserves position without snapping")
	for tick in range(720): race.step(1./120.,[disruptive,{"throttle":1.}])
	check(p.distance>initial_distance+800. and p.speed>130.,"Autopilot continues down the course despite human braking")
	check(p.time==finish_time and p.lap==lap and p.rank==1,"Victory movement cannot change finish time, lap or winner")
	check(p.weapon=="missile" and p.boost==0. and p.engine_power>.5 and race.weapons.missiles.is_empty(),"Finishers retain equipment without firing or boosting")
	check("drone" in p.victory_mounts and p.drone_time==0.,"Active mounts settle to idle without vanishing")
	var vfx:Node3D=load("res://src/weapon_vfx.gd").new();root.add_child(vfx);vfx.configure(race);vfx.update()
	check(not vfx.mounts[0].missile.visible and vfx.turrets[0].visible,"Replay retains the sentry on the single mount; queued missile stays in inventory")
	check(race.weapons.shots.is_empty(),"Finished active weapons cannot disrupt opponents still racing")
	race.weapons.pulses.append({"id":99,"owner":0,"frame":Race.Weapons.pose(race,race.racers[1]),"age":0.,"radius":0.,"hit":{}})
	race.weapons.step_emp(race,.1)
	check(race.racers[1].emp_time==0. and not race.weapons.pulses[0].active,"A finisher's lingering EMP is cosmetic only")
	vfx.queue_free()
	check(race.racers[1].distance>100. and not race.racers[1].finished,"Unfinished opponent remains in the race")
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.transform=Transform3D(p.victory_pose.basis,p.victory_pose*Vector3(0,7,-23))
	camera.fov=98.
	var entry:Transform3D=camera.transform
	Victory.camera_update(camera,p.victory_pose,race.track.sample(p.distance),0.,race.track.obstacles)
	check(camera.transform.is_equal_approx(entry) and camera.fov==98.,"Handoff starts from the existing camera transform and lens")
	var shots:={}
	for age in [2.,5.5,10.5,15.5]:
		Victory.camera_update(camera,p.victory_pose,race.track.sample(p.distance),age,race.track.obstacles,true)
		shots[camera.get_meta("victory_shot")]=true
		var aim:Vector3=p.victory_pose.origin+p.victory_pose.basis.y
		check((-camera.basis.z).dot((aim-camera.position).normalized())>.99,"Every cinematic shot frames the vehicle")
	check(shots.size()==4,"Four distinct replay angles cycle automatically")
	var distance:float=p.distance
	var clock:float=race.clock
	race.over=true
	for tick in range(240): race.step(1./120.,[])
	check(p.distance>distance+250. and race.clock==clock and p.time==finish_time,"Results keep moving without changing the race clock or result")
	for feature in ["loop","tunnel","split","jump","flight","tube"]:
		for i in range(race.track.nodes.size()):
			var n:Dictionary=race.track.nodes[i]
			if not (n.get(feature,false) if feature in ["loop","tunnel"] else n.feature==feature): continue
			p.distance=i*race.track.step
			Victory.step(p,race.track,1./120.,race.clock)
			check(p.victory_pose.is_finite() and not p.crashed,"Victory pilot traverses "+feature)
			Victory.camera_update(camera,p.victory_pose,race.track.sample(p.distance),15.5,race.track.obstacles,true)
			check(camera.transform.is_finite(),"Replay camera remains valid in "+feature)
			break
	camera.queue_free()
	if "--render" in OS.get_cmdline_user_args(): await render_scene()
	print("VICTORY_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func render_scene()->void:
	var game:Node=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.human_count=2;game.next_seed=31;game.start_local()
	game.set_process(false);game.set_physics_process(false)
	game.race.countdown=0.;game.race.clock=90.;game.race.vfx_clock=90.
	var p:Dictionary=game.race.racers[0]
	p.distance=game.race.track.length*game.race.laps-1.;p.speed=225.;p.startup=1.
	p.lap=game.race.laps;p.checkpoint_index=game.race.checkpoints.gates.size()
	p.weapon="missile";p.drone_time=2.
	game.world.update_camera(game.views[0].camera,0,0.,true)
	game.race.step(.02,[{"throttle":1.},{},{},{},{},{}])
	var output:="C:/dev/ion-rush-captures/victory"
	DirAccess.make_dir_recursive_absolute(output)
	for shot in range(4):
		for tick in range(576):
			game.race.step(1./120.,[{},{},{},{},{},{}])
			game.world.update_camera(game.views[0].camera,0,1./120.)
		game.world.update_ships()
		check(game.world.ships[0].get_node("EngineLight").light_energy>0.,"Victory lap keeps visible exhaust and jet lighting")
		game.world.update_camera(game.views[1].camera,1,1./120.)
		for view in game.views: view.hud.queue_redraw()
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("shot-%d.png"%shot))
	check(not game.views[1].camera.has_meta("victory_entry"),"Split-screen keeps the unfinished player's chase camera")
	game.pause_local()
	var frozen:Transform3D=game.views[0].camera.transform
	var distance:float=p.distance
	game._physics_process(.2);game._process(.2)
	check(p.distance==distance and game.views[0].camera.transform==frozen,"Pause freezes both victory pilot and camera")
	game.resume_local();game.race.over=true
	game._physics_process(.02);game._process(.02)
	check(game.views[1].camera.has_meta("victory_entry"),"DNF view follows the winner once results begin")
	for view in game.views: view.hud.queue_redraw()
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("results.png"))
	game.queue_free()
	await process_frame
