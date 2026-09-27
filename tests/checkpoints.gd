extends SceneTree
const Race=preload("res://src/race.gd")
const Flight=preload("res://src/flight.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func cross(race:RefCounted,p:Dictionary,gate:Dictionary,side:float=0.,height:float=5.,reverse:bool=false)->void:
	p.airborne=true;p.air_time=1.
	p.checkpoint_before=gate.frame*Vector3(side,height,4. if reverse else -4.)
	p.air_position=gate.frame*Vector3(side,height,-4. if reverse else 4.)
	race.update_lap(p)
func run()->void:
	for seed_value in range(31,37):
		for difficulty in ["easy","normal","hard"]:
			var r:=Race.new([{"slot":0}],seed_value,3,difficulty)
			check(r.checkpoints.gates.size()>=3 and r.checkpoints.gates.size()<=4,"Sparse gates on each track profile")
			for loop in r.track.loops:
				check(r.checkpoints.gates.any(func(g):return g.loop and absf(g.u-(loop.start+loop.end)*.5)<.003),"Every loop has a midpoint checkpoint")
			for gate in r.checkpoints.gates:
				check(not r.track.sample(gate.distance).air_gap,"Gate does not require landing on missing deck")
	var race:=Race.new([{"slot":0},{"slot":1}],31,1)
	race.countdown=0.;race.clock=20.
	var p:Dictionary=race.racers[0]
	var first:Dictionary=race.checkpoints.gates[0]
	cross(race,p,race.checkpoints.gates[1])
	check(p.checkpoint_index==0,"Out-of-order gates cannot be collected")
	cross(race,p,first,0.,5.,true)
	check(p.checkpoint_index==0,"Reverse crossing does not count")
	cross(race,p,first,first.width+10.)
	check(p.checkpoint_index==0,"Flying beside gate does not count")
	cross(race,p,first,0.,first.height+10.)
	check(p.checkpoint_index==0,"Flying above gate does not count")
	p.distance=first.distance+180.
	race.update_lap(p)
	check(p.checkpoint_missed and race.can_reset(p),"Skipped feature offers manual return")
	var expected:float=race.checkpoints.return_distance(p)
	check(expected<first.distance-100.,"Missed loop returns before the loop approach")
	# World location is retained for the wreck; recovery rewinds track progress.
	p.air_frame=first.frame.basis;p.air_velocity=Vector3.ZERO
	race.step(.01,[{"reset":true},{}])
	for i in range(260): race.step(.01,[{},{}])
	check(not p.crashed and not p.checkpoint_missed and p.distance>=expected and p.distance<first.distance,"Reset costs recovery time and returns before missed checkpoint")
	check(p.checkpoint_index==0,"Respawning never grants the missing checkpoint")
	p.distance=race.track.length+2.;p.checkpoint_before=Vector3.ZERO
	race.update_lap(p)
	check(not p.finished and p.lap==1 and p.checkpoint_missed,"Finish without checkpoints cannot award lap")
	for gate in race.checkpoints.gates:
		cross(race,p,gate)
	check(race.checkpoints.complete(p),"In-order airborne crossings satisfy all checkpoints")
	p.distance=race.track.length+2.;race.update_lap(p)
	check(p.finished and p.lap==2,"Finish counts after all required gates")
	# Landing can skip route length when no gate was omitted. The former hidden
	# travelled-distance requirement would reject this short flight.
	var shortcut:=Race.new([{"slot":0}],31)
	shortcut.countdown=0.;shortcut.clock=10.
	var pilot:Dictionary=shortcut.racers[0]
	pilot.checkpoint_index=1
	var start:float=shortcut.checkpoints.gates[0].distance+50.
	var destination:float=shortcut.checkpoints.gates[1].distance-180.
	var n:Dictionary=shortcut.track.sample(destination)
	pilot.distance=start;pilot.airborne=true;pilot.air_time=1.;pilot.air_travel=2.
	pilot.air_position=shortcut.Track.point(n,0.,2.);pilot.air_frame=n.frame
	pilot.air_velocity=n.frame.z*180.-n.frame.y*30.;pilot.air_entry_speed=200.
	shortcut.step(.05,[{"throttle":1.}])
	check(not pilot.crashed and not pilot.airborne and pilot.distance>start+200.,"Shortcut landing between gates succeeds despite short travelled distance")
	check(pilot.checkpoint_index==1 and not pilot.checkpoint_missed,"Legal shortcut does not fabricate or miss checkpoint credit")
	if "--render" in OS.get_cmdline_user_args(): await render_scene()
	print("CHECKPOINT_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
func render_scene()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game)
	game.human_count=1;game.next_seed=31;game.start_local()
	game.set_process(false);game.set_physics_process(false)
	game.race.countdown=0.;game.race.clock=12.
	var gate:Dictionary=game.race.checkpoints.gates[0]
	for i in range(game.race.racers.size()):
		var pilot:Dictionary=game.race.racers[i]
		pilot.distance=gate.distance-65.+i*300.;pilot.x=0.;pilot.speed=240.;pilot.startup=1.;pilot.engine_power=1.;pilot.thrust=1.
	game.world.update_ships();game.world.update_camera(game.views[0].camera,0,0.,true)
	game.views[0].hud.visible=true;game.views[0].hud.queue_redraw()
	for frame in range(30): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/checkpoint-loop.png")
	var pilot:Dictionary=game.race.racers[0]
	pilot.distance=gate.distance+180.;game.race.update_lap(pilot)
	check(pilot.checkpoint_missed and game.race.can_reset(pilot),"Grounded missed checkpoint enables Y notice")
	game.world.update_ships();game.world.update_camera(game.views[0].camera,0,0.,true)
	game.views[0].hud.queue_redraw()
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/checkpoint-missed.png")
	game.queue_free();await process_frame
