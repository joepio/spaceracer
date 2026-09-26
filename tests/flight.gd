extends SceneTree
const Race=preload("res://src/race.gd")
const Flight=preload("res://src/flight.gd")
const Chase=preload("res://src/chase.gd")
const Track=preload("res://src/track.gd")
var failures:=0
var checks:=0

func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)

func _initialize()->void:
	call_deferred("run")

func approach(p:Dictionary,n:Dictionary,distance:float,lateral:float=0.0)->void:
	p.airborne=true
	p.crashed=false
	p.wreck_wait=false
	p.recovery=0.0
	p.distance=distance
	p.air_position=Track.point(n,lateral,1.8)
	p.air_velocity=n.frame.z*220-n.frame.y*20
	p.air_frame=n.frame
	p.air_time=.5
	p.air_travel=0.0
	p.air_roll=0.0
	p.air_rates=Vector3.ZERO
	p.trim=0.0

func guided_return(seed_value:int)->void:
	# Isolate manual takeoff/return from compulsory jump sections tested separately.
	var race:=Race.new([{"slot":0,"bot":false}],seed_value,3,"easy")
	race.countdown=0
	var p:Dictionary=race.racers[0]
	# Use the opening sweeper as a landing approach, before the magnetic loops.
	p.distance=0.0
	p.speed=265.0
	for tick in range(240):
		var controls:Dictionary=race.bot(p)
		controls.trim=-1.0
		controls.brake=0.0
		race.step(1.0/120,[controls])
		if p.airborne: break
	check(p.airborne,"Guided return begins with real player-input takeoff")
	var launch_distance:float=p.distance
	for tick in range(1200):
		if not p.airborne: break
		var hit:Dictionary=race.track.project(p.air_position,p.distance,p.air_travel*1.35+100)
		var n:Dictionary=hit.node
		var height:float=(p.air_position-n.p).dot(n.frame.y)
		var aim:Dictionary=race.track.sample(hit.distance+100)
		# Climb first, then command the approach; direct flight can land much sooner.
		var target_height:=30. if p.air_time<.8 else 1.3
		var goal:Vector3=aim.frame.z*230+n.frame.y*clampf((target_height-height)*2,-45,25)+n.frame.x*clampf(hit.lateral*4,-100,100)
		var frame:Basis=p.air_frame
		var pitch:=clampf(-atan2(goal.dot(frame.y),goal.dot(frame.z))*2,-1,1)
		var yaw:=clampf(-atan2(goal.dot(frame.x),goal.dot(frame.z))*5,-1,1)
		var roll:=clampf(-atan2(aim.frame.y.dot(frame.x),aim.frame.y.dot(frame.y))*2,-1,1)
		race.step(1.0/120,[{"throttle":.65,"brake":.2 if p.speed>245 else 0.0,"trim":pitch,"steer":yaw,"strafe":roll}])
	check(not p.airborne and not p.crashed and p.recovery==0 and p.distance>launch_distance+200,"A controlled full flight can return to a real seeded track")

func handling_checks()->void:
	var race:=Race.new([{"slot":0,"bot":false}],31)
	var p:Dictionary=race.racers[0]
	p.air_frame=Basis.IDENTITY
	p.air_velocity=Vector3(0,0,265)
	for tick in range(120): Flight.integrate_air(p,1.0/120,1,0,1,0)
	check(p.air_frame.z.dot(Vector3.BACK)>.999,"Roll does not secretly yaw the nose")
	check(p.air_roll>2.1,"Full roll has fighter authority, not a capped bank target")
	var banked:=Race.new([{"slot":0}],31).racers[0]
	banked.air_frame=Basis(Vector3.BACK,.65);banked.air_velocity=Vector3(0,0,235)
	for tick in range(120): Flight.integrate_air(banked,1./120.,0.,0.,1.,0.)
	check(banked.air_velocity.x< -5,"Holding a bank bends the flight path into the bank at reduced airspeed")
	for tick in range(120): Flight.integrate_air(p,1.0/120,0,0,1,0)
	var held:Basis=p.air_frame
	for tick in range(60): Flight.integrate_air(p,1.0/120,0,0,1,0)
	check(held.y.dot(p.air_frame.y)>.999,"Neutral stick holds bank instead of levelling automatically")
	for axis in ["pitch","yaw"]:
		p.air_frame=Basis.IDENTITY
		p.air_velocity=Vector3(0,0,265)
		p.air_rates=Vector3.ZERO
		p.trim=-1.0 if axis=="pitch" else 0.0
		for tick in range(60): Flight.integrate_air(p,1.0/120,0,1 if axis=="yaw" else 0,1,0)
		check(p.air_frame.z.y>.3 if axis=="pitch" else p.air_frame.z.x<-.2,"Independent %s rotates the correct body axis"%axis)
		check(absf(p.air_frame.determinant()-1)<.0001,"Flight frame stays orthonormal")

func transition_checks()->void:
	var race:=Race.new([{"slot":0,"bot":false}],31)
	race.countdown=0
	var p:Dictionary=race.racers[0]
	p.speed=265.0
	p.distance=500.0
	var camera:=Camera3D.new()
	root.add_child(camera)
	var warning_frames:=0
	var max_relative_step:=0.0
	var previous_offset:=Vector3.ZERO
	for tick in range(240):
		var before:=Flight.pose(p,race.track.sample(p.distance),race.clock)
		Chase.update(camera,before,p.speed,false,1.0/120,tick==0)
		previous_offset=camera.position-before.origin
		race.step(1.0/120,[{"throttle":1.0,"trim":-1.0}])
		var after:=Flight.pose(p,race.track.sample(p.distance),race.clock)
		Chase.update(camera,after,p.speed,false,1.0/120)
		max_relative_step=maxf(max_relative_step,(camera.position-after.origin).distance_to(previous_offset))
		if not p.airborne and p.unload>.45 and p.lift>.3: warning_frames+=1
		if p.airborne:
			check(p.air_position.distance_to(before.origin+p.air_velocity/120)<.001,"Takeoff preserves position and measured momentum with no kick")
			var expected:=Flight.ground_pose(p,race.track.sample(p.distance),race.clock)
			check(p.air_frame.z.dot(expected.basis.z)>.99999,"Takeoff preserves the visible attitude")
			break
	check(p.airborne,"Sustained back-stick eventually releases magnetic adhesion")
	check(warning_frames>35,"Visible lift warning lasts long enough to react before takeoff")
	check(max_relative_step<.7,"Chase camera offset has no takeoff discontinuity")
	# A pilot can abort the launch during the warning by pushing forward.
	var abort:=Race.new([{"slot":0,"bot":false}],31)
	abort.countdown=0
	var q:Dictionary=abort.racers[0]
	q.speed=265.0
	for tick in range(65): abort.step(1.0/120,[{"throttle":1.0,"trim":-1.0}])
	check(not q.airborne and q.lift>.3,"Partial takeoff has a recoverable warning phase")
	for tick in range(180): abort.step(1.0/120,[{"throttle":1.0,"trim":1.0}])
	check(not q.airborne and q.lift<.03,"Forward stick settles the craft without forced launch")
	# A moving vehicle remains framed at speed; only relative attitude is damped.
	var pose:=Transform3D(Basis.IDENTITY,Vector3.ZERO)
	Chase.update(camera,pose,400,false,0,true)
	var offset:=camera.position
	pose.origin=Vector3(0,0,400)
	Chase.update(camera,pose,400,false,1.0/60)
	check((camera.position-pose.origin).distance_to(offset)<.001,"Camera smoothing introduces no speed-dependent translation lag")
	var old_rotation:=camera.basis.get_rotation_quaternion()
	pose.basis=Basis(Vector3.BACK,PI*.9)
	Chase.update(camera,pose,400,false,1.0/120)
	check(old_rotation.angle_to(camera.basis.get_rotation_quaternion())<.2,"Camera smoothly follows a large attitude change")
	camera.free()

func run()->void:
	handling_checks()
	transition_checks()
	check(Flight.ground_basis(Basis.IDENTITY,0,-1,0).z.y>.3,"Pull back raises +Z nose")
	check(Flight.ground_basis(Basis.IDENTITY,0,1,0).z.y<-.15,"Push forward lowers nose")
	var race:=Race.new([{"slot":0,"bot":false}],31)
	race.countdown=0
	var p:Dictionary=race.racers[0]
	p.distance=500.0
	p.speed=250.0
	for tick in range(240):
		race.step(1.0/120,[{"throttle":1.0,"trim":-1.0}])
		if p.airborne: break
	check(p.airborne,"Full pull-back launches at speed without needing a crest")
	var takeoff:float=p.distance
	var frame:Basis=p.air_frame
	for tick in range(30): race.step(1.0/120,[{"throttle":1.0}])
	check(p.airborne and p.air_position.distance_to(Track.point(race.track.sample(takeoff),p.x,1.3))>30,"Flight travels independently in world space")
	check(p.distance==takeoff,"Airborne time cannot award track/lap progress")
	check(frame.z.dot(p.air_frame.z)>.98,"Neutral air attitude stays independent of track curves")
	for tick in range(20): race.step(1.0/120,[{"trim":1.0,"steer":.6,"strafe":.5}])
	check(frame.z.dot(p.air_frame.z)<.999,"Air pitch and turn change attitude")
	check(p.air_roll>.05,"Air steering banks the craft")
	for inverted in [false,true]:
		var distance:=500.0
		if inverted:
			for i in range(race.track.nodes.size()):
				if race.track.nodes[i].frame.y.y<-.8:
					distance=i*race.track.step
					break
		var n:Dictionary=race.track.sample(distance)
		approach(p,n,distance)
		Flight.step(p,race.track,.05,0,0,0,0)
		check(not p.airborne and not p.crashed,"Aligned swept landing, inverted=%s"%inverted)
		check(p.distance>distance,"Landing reconnects at actual road location")
	var n:Dictionary=race.track.sample(500)
	approach(p,n,500,n.width+20)
	Flight.step(p,race.track,.05,0,0,0,0)
	check(p.airborne and p.distance==500,"Missing the ribbon does not magnetically snap onto it")
	approach(p,n,500)
	p.air_frame=n.frame*Basis(Vector3.BACK,PI)
	Flight.step(p,race.track,.05,0,0,0,0)
	check(p.crashed and p.wreck_wait and p.recovery==0,"Inverted impact enters the wreck animation before automatic recovery")
	approach(p,n,500)
	p.air_position=Track.point(n,0,-2)
	p.air_velocity=n.frame.z*220+n.frame.y*50
	Flight.step(p,race.track,.05,0,0,0,0)
	check(p.crashed,"Underside crossing cannot count as a landing")
	approach(p,n,500)
	p.air_position=Track.point(n,0,150)
	p.air_time=10.1
	Flight.step(p,race.track,1.0/120,0,0,0,0)
	check(p.crashed and not p.airborne,"Unrecovered flight times out into respawn")
	race.step(1.,[{}])
	check(p.crashed and p.wreck_wait and p.recovery==0,"Wreck stays visible during the automatic recovery delay")
	race.step(1.01,[{}])
	check(p.recovery==0 and not p.crashed and p.speed==90 and p.x==0,"Crash respawns on last safe track position")
	check(p.launch_cooldown>0,"Respawn cannot immediately relaunch from a held stick")
	var beyond:Dictionary=race.track.sample(race.track.length+20)
	var projection:Dictionary=race.track.project(Track.point(beyond,0,2),race.track.length-50,150)
	check(absf(projection.distance-race.track.length-20)<1,"Landing projection unwraps correctly across lap seam")
	for seed_value in [1,42]: guided_return(seed_value)
	var ship=load("res://src/ship.gd").build(Color.CYAN)
	root.add_child(ship)
	var grid:=Race.new([{"slot":0,"bot":false}],31)
	grid.step(1.0/120,[{"trim":-1.0}])
	var pilot:Dictionary=grid.racers[0]
	var ship_type=load("res://src/ship.gd")
	ship_type.animate_controls(ship,pilot)
	check(ship.get_node("WingControlL").rotation.x>.5 and ship.get_node("WingControlR").rotation.x>.5,"Pull-back visibly raises both trailing edges, even during countdown")
	grid.step(1.0/120,[{"strafe":1.0}])
	ship_type.animate_controls(ship,pilot)
	check(ship.get_node("WingControlL").rotation.x>0 and ship.get_node("WingControlR").rotation.x<0,"Right-stick strafe/roll moves ailerons in opposite directions")
	check(absf(ship.get_node("RudderL").rotation.y)<.001,"Right stick leaves rudders neutral")
	grid.step(1.0/120,[{"steer":1.0,"brake":1.0}])
	ship_type.animate_controls(ship,pilot)
	check(ship.get_node("RudderL").rotation.y<-.5 and ship.get_node("WingControlL").rotation.x>.5,"Left-stick turn moves rudders and braking deploys flaps")
	# Exercise the public airborne inputs independently, not just the integrator.
	for control in ["steer","strafe"]:
		var test:=Race.new([{"slot":0}],31,1,"easy")
		test.countdown=0
		var pilot_air:Dictionary=test.racers[0]
		var node:Dictionary=test.track.sample(500.)
		approach(pilot_air,node,500.)
		pilot_air.air_position=Track.point(node,0,100.)
		pilot_air.air_velocity=node.frame.z*265.
		for tick in range(30): test.step(1./120.,[{control:1.,"throttle":1.}])
		if control=="steer": check(pilot_air.air_rates.y<-.5 and absf(pilot_air.air_rates.z)<.001,"Left-stick input yaws without rolling")
		else: check(pilot_air.air_rates.z>1.5 and absf(pilot_air.air_rates.y)<.001,"Right-stick input rolls without yawing")
	# Reset preserves its cost except a depleted hull gets a small survival reserve.
	var reset_race:=Race.new([{"slot":0}],31,1,"normal")
	reset_race.countdown=0
	var reset_p:Dictionary=reset_race.racers[0]
	reset_p.energy=40.
	reset_race.step(.01,[{"reset":true}])
	check(reset_p.recovery==0 and reset_p.energy==40.,"Y is ignored while on the road")
	reset_race.step(.01,[{}])
	var reset_takeoff:float=reset_race.track.jumps[0].takeoff
	approach(reset_p,reset_race.track.sample(reset_takeoff),reset_takeoff)
	reset_p.air_position+=Vector3.UP*80.
	reset_race.step(.01,[{"reset":true}])
	check(reset_p.recovery>1.9 and reset_p.manual_reset and reset_p.energy==15.,"Y spends 25 energy and starts two-second recovery")
	for tick in range(239): reset_race.step(.01,[{"reset":true}])
	check(reset_p.recovery==0 and reset_p.energy==15. and reset_p.distance<reset_takeoff,"Held Y resets once, preserves the cost and returns before the jump")
	check(Track.supported(reset_race.track.sample(reset_p.distance),reset_p.x,5.8),"Manual recovery returns onto supported road")
	reset_race.step(.01,[{}])
	approach(reset_p,reset_race.track.sample(500.),500.)
	reset_race.step(.01,[{"reset":true}])
	for tick in range(239): reset_race.step(.01,[{}])
	check(reset_p.energy==25. and reset_p.recovery==0,"Depleted hull rebuild has enough reserve to survive a mandatory landing")
	var input_bridge=load("res://src/bridge.gd").new()
	input_bridge.frames={"owned":{"buttons":8},"other":{"buttons":0}}
	input_bridge.frame_at=Time.get_ticks_msec()
	check(input_bridge.controls("owned").reset and not input_bridge.controls("other").reset,"GameNight Y reset belongs only to its controller owner")
	input_bridge.frame_at=-10000
	check(not input_bridge.controls("owned").reset,"Stale controller frames release reset")
	input_bridge.free()
	ship.free()
	print("FLIGHT_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
