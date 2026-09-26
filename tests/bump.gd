extends SceneTree
const Race=preload("res://src/race.gd")
const Bump=preload("res://src/bump.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func setup()->RefCounted:
	var race:=Race.new([{"slot":2},{"slot":7}],31)
	race.countdown=0.;race.clock=5.
	# Isolate collision damage from the starting straight repair lane.
	for n in race.track.nodes: n.zone=""
	for p in race.racers: p.distance=100.;p.x=0.;p.speed=200.;p.ignited=true;p.startup=1.
	return race
func _initialize()->void: call_deferred("run")
func run()->void:
	for side in [-1.,1.]:
		var race:=setup();var a:Dictionary=race.racers[0];var b:Dictionary=race.racers[1]
		b.x=side*12.
		var input:Dictionary={"left":side<0.,"right":side>0.,"throttle":1.}
		for tick in range(28): race.step(1./120.,[input,{"throttle":1.}])
		check(b.energy==86.,"Side bump reaches rival and deals exactly one 14-point hit, side %s"%side)
		check(a.energy==100. and side*a.x>0.,"Attack moves the craft in the chosen direction without self damage")
		check(a.input_strafe==0.,"Shoulder buttons do not produce analog strafe input")
		for tick in range(130): Bump.begin(a,input,1./120.,0.)
		check(a.bump_time==0. and a.bump_cooldown==0.,"Holding shoulder does not repeat after cooldown")
		Bump.begin(a,{},.01,0.);Bump.begin(a,input,.01,0.)
		check(a.bump_time==Bump.DURATION,"Release and press rearms attack after cooldown")
		Bump.begin(a,{},.1,0.);Bump.begin(a,input,.1,0.)
		check(a.bump_time<Bump.DURATION,"Early re-press cannot bypass shared cooldown")
	var race:=setup();var a:Dictionary=race.racers[0];var b:Dictionary=race.racers[1]
	b.x=8.;race.resolve_contacts()
	check(b.energy==100.,"Ordinary contact does not become a damaging bump")
	Bump.begin(a,{"right":true},.01,0.)
	Bump.strike(race,a,b,Vector2.UP);Bump.strike(race,a,b,Vector2.DOWN);Bump.strike(race,a,b,Vector2.LEFT)
	check(b.energy==100.,"Rear, nose and wrong-side contacts do not deal attack damage")
	Bump.strike(race,a,b,Vector2.RIGHT)
	for i in range(10): Bump.strike(race,a,b,Vector2.RIGHT)
	check(b.energy==86. and b.shield_hit>0.,"Contact solver iterations produce one hit and visible shield feedback")
	for field in ["crashed","airborne","finished","recovery","warp_time","emp_time"]:
		Bump.initialize(a);a[field]=true if field in ["crashed","airborne","finished"] else 1.
		Bump.begin(a,{"left":true},.01,0.)
		check(a.bump_time==0.,"Bump rejected during "+field)
		a[field]=false if field in ["crashed","airborne","finished"] else 0.
	Bump.initialize(a);Bump.begin(a,{"left":true,"right":true},.01,0.)
	check(a.bump_time==0.,"Simultaneous shoulders cancel")
	Bump.initialize(a);Bump.begin(a,{"right":true},.01,1.);Bump.begin(a,{"right":true},.01,0.)
	check(a.bump_time==0.,"Countdown hold does not prefire an attack")
	Bump.initialize(a);Bump.begin(a,{"right":true},.01,0.);b.bump_guard=0.;b.energy=10.
	Bump.strike(race,a,b,Vector2.RIGHT)
	check(b.crashed and b.wreck_wait and b.speed==0.,"Lethal side hit creates a stopped wreck requiring manual reset")
	var healthy:float=a.energy
	Bump.strike(race,b,a,Vector2.LEFT)
	check(a.energy==healthy,"A wreck cannot deal a return bump")
	var analog:=setup();analog.racers[1].distance=500.
	for i in range(12): analog.step(1./120.,[{"strafe":1.,"throttle":1.},{}])
	check(analog.racers[0].slip>30. and analog.racers[0].bump_time==0.,"Right stick keeps strong continuous strafe without triggering attack")
	var bridge=load("res://src/bridge.gd").new()
	bridge.frame_at=Time.get_ticks_msec();bridge.frames["pad"]={"buttons":1<<4,"axes":[0,0,32767,0,0,0]}
	var c:Dictionary=bridge.controls("pad")
	check(c.left and not c.right and c.strafe==1.,"GameNight LB and right stick retain independent actions")
	bridge.frames["pad"].buttons=1<<5;c=bridge.controls("pad")
	check(c.right and not c.left,"GameNight RB maps right bump")
	bridge.free()
	print("BUMP_TESTS %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
