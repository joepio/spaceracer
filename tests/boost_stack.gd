extends SceneTree
const Race=preload("res://src/race.gd")
const Obstacles=preload("res://src/obstacles.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func fresh(pad:bool=false)->RefCounted:
	var race:=Race.new([{"slot":0}],31)
	race.countdown=0.;race.clock=20.;race.checkpoints.gates.clear()
	race.weapons.pickups.clear();race.track.hazards=Obstacles.new()
	for i in range(race.track.nodes.size()):
		var n:Dictionary=race.track.nodes[i]
		n.p=Vector3(0,20,i*race.track.step);n.frame=Basis.IDENTITY;n.curve=0.;n.crest=0.;n.slope=0.;n.width=500.;n.zone="boost" if pad else ""
		n.air_gap=false;n.loop=false;n.split_gap=0.;n.shape_angle=0.;n.feature="ribbon";n.rails=false
	var p:Dictionary=race.racers[0]
	p.distance=200.;p.lap=2;p.x=0.;p.speed=265.;p.startup=1.;p.ignited=true;p.engine_power=1.
	return race
func _initialize()->void: call_deferred("run")
func run()->void:
	var speeds:Array[float]=[]
	for mode in ["paid","pad","stack"]:
		var race:=fresh(mode!="paid");var p:Dictionary=race.racers[0]
		for i in range(96): race.step(1./120.,[{"throttle":1.,"boost":mode!="pad"}])
		speeds.append(p.speed);print("BOOST_MODE ",mode," kmh=",p.speed*3.6)
		check(not p.crashed and not p.airborne,"Stacked boost stays controllable on straight road")
	check(speeds[2]>speeds[0]+60. and speeds[2]>speeds[1]+60.,"Boost plus strip is substantially faster than either alone")
	check(Race.speed_instability(330.,0.)==0. and Race.speed_instability(490.,0.)>.9,"Ordinary racing retains grip; extreme speed loses grip")
	check(Race.speed_instability(490.,1.)<Race.speed_instability(490.,0.)*.3,"Nose-down trim restores high-speed stability")
	var residual:Array[float]=[]
	for mode in ["cruise","extreme","planted"]:
		var race:=fresh(mode!="cruise");var p:Dictionary=race.racers[0]
		p.speed=265. if mode=="cruise" else 475.;p.slip=70.;p.boost=1. if mode!="cruise" else 0.
		for i in range(12): race.step(1./120.,[{"throttle":1.,"trim":1. if mode=="planted" else 0.}])
		residual.append(absf(p.slip))
	check(residual[1]>residual[0]*1.5 and residual[2]<residual[1],"Extreme speed carries more sideways momentum; grip input counters it")
	print("BOOST_STACK_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
