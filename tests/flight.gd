extends SceneTree
const Race=preload("res://src/race.gd")
const Flight=preload("res://src/flight.gd")
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
	p.recovery=0.0
	p.distance=distance
	p.air_position=Track.point(n,lateral,1.8)
	p.air_velocity=n.frame.z*220-n.frame.y*20
	p.air_frame=n.frame
	p.air_time=.5
	p.air_travel=0.0
	p.air_roll=0.0
	p.trim=0.0

func guided_return(seed_value:int)->void:
	var race:=Race.new([{"slot":0,"bot":false}],seed_value)
	race.countdown=0
	var p:Dictionary=race.racers[0]
	p.distance=500.0
	p.speed=265.0
	for tick in range(80):
		race.step(1.0/120,[{"throttle":1.0,"trim":-1.0}])
		if p.airborne: break
	check(p.airborne,"Guided return begins with real player-input takeoff")
	var launch_distance:float=p.distance
	for tick in range(1200):
		if not p.airborne: break
		var hit:Dictionary=race.track.project(p.air_position,p.distance,p.air_travel*1.35+100)
		var n:Dictionary=hit.node
		var height:float=(p.air_position-n.p).dot(n.frame.y)
		var aim:Dictionary=race.track.sample(hit.distance+maxf(100,height*4))
		var goal:Vector3=aim.p+aim.frame.y*1.3-p.air_position
		var frame:Basis=p.air_frame
		var pitch:=clampf(-atan2(goal.dot(frame.y),goal.dot(frame.z))*2,-1,1)
		var turn:=clampf(-atan2(goal.dot(frame.x),goal.dot(frame.z))*3,-1,1)
		race.step(1.0/120,[{"throttle":.6,"brake":.25 if p.speed>210 else 0.0,"trim":pitch,"steer":turn,"strafe":clampf(-hit.lateral*.07,-1,1)}])
	check(not p.airborne and not p.crashed and p.recovery==0 and p.distance>launch_distance+200,"A controlled full flight can return to a real seeded track")

func run()->void:
	check(Flight.ground_basis(Basis.IDENTITY,0,-1,0).z.y>.3,"Pull back raises +Z nose")
	check(Flight.ground_basis(Basis.IDENTITY,0,1,0).z.y<-.15,"Push forward lowers nose")
	var race:=Race.new([{"slot":0,"bot":false}],31)
	race.countdown=0
	var p:Dictionary=race.racers[0]
	p.distance=500.0
	p.speed=250.0
	for tick in range(80):
		race.step(1.0/120,[{"throttle":1.0,"trim":-1.0}])
		if p.airborne: break
	check(p.airborne,"Full pull-back launches at speed without needing a crest")
	var takeoff:float=p.distance
	var frame:Basis=p.air_frame
	for tick in range(30): race.step(1.0/120,[{"throttle":1.0}])
	check(p.airborne and p.air_position.distance_to(Track.point(race.track.sample(takeoff),p.x,1.3))>30,"Flight travels independently in world space")
	check(p.distance==takeoff,"Airborne time cannot award track/lap progress")
	check(frame.z.dot(p.air_frame.z)>.98,"Neutral air attitude does not follow track curves")
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
	check(p.crashed and p.recovery==2,"Inverted impact on normal road crashes")
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
	race.step(2.1,[{}])
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
	grid.step(1.0/120,[{"steer":1.0}])
	ship_type.animate_controls(ship,pilot)
	check(ship.get_node("WingControlL").rotation.x>0 and ship.get_node("WingControlR").rotation.x<0,"Steering moves ailerons in opposite directions")
	grid.step(1.0/120,[{"strafe":1.0,"brake":1.0}])
	ship_type.animate_controls(ship,pilot)
	check(ship.get_node("RudderL").rotation.y<-.5 and ship.get_node("WingControlL").rotation.x>.5,"Strafe moves rudders and braking deploys flaps")
	ship.free()
	print("FLIGHT_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
