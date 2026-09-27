extends SceneTree
const Race=preload("res://src/race.gd")
const Flight=preload("res://src/flight.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	for case in ["finish","lap","backwards","outside","high","shortcut"]:
		var race:=Race.new([{"slot":0}],31,3,"normal","cell")
		race.countdown=0.;race.clock=90.
		var p:Dictionary=race.racers[0]
		p.lap=1 if case=="lap" else 3
		p.checkpoint_index=0 if case=="shortcut" else race.checkpoints.gates.size()
		p.distance=race.track.length*p.lap-30.
		if case=="shortcut": p.distance=500.
		var n:Dictionary=race.track.sample(0.)
		p.airborne=true;p.air_time=2.;p.air_travel=25.;p.speed=220.;p.startup=1.
		p.air_position=n.p+n.frame.z*(5. if case=="backwards" else -5.)+n.frame.y*(140. if case=="high" else 25.)
		if case=="outside": p.air_position+=n.frame.x*(n.width+20.)
		p.air_frame=n.frame*Basis(Vector3.UP,PI) if case=="backwards" else n.frame
		p.air_velocity=p.air_frame.z*220.
		race.step(.05,[{"throttle":1.}])
		if case=="finish":
			check(p.finished and p.airborne and race.over,"Crossing the finish in flight wins without landing")
			check(p.time>90. and p.time<90.05,"Air finish time uses the swept crossing instant")
			var pose:Transform3D=Flight.pose(p,n,race.clock)
			race.step(1./120.,[])
			check(p.has("victory_pose") and p.victory_pose.origin.distance_to(pose.origin)<5.,"Air finish hands off smoothly to victory pilot")
		elif case=="lap": check(p.lap==2 and p.airborne and not p.finished,"An airborne lap crossing also counts immediately")
		else: check(not p.finished,"Reject invalid air crossing: "+case)
	# The Cell has no city street underneath it: its old generic kill plane was invisible.
	var cell:=Race.new([{"slot":0}],31,3,"normal","cell")
	var p:Dictionary=cell.racers[0]
	p.airborne=true;p.air_time=20.;p.air_position=Vector3(0,-200,0);p.air_velocity=Vector3(0,0,220)
	Flight.step(p,cell.track,.01,0.,0.,1.,0.)
	check(not p.crashed,"Cell flight is not destroyed by the city's invisible floor")
	print("AIR_FINISH_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
