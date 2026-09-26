extends SceneTree
const Race=preload("res://src/race.gd")
const Flight=preload("res://src/flight.gd")
const Track=preload("res://src/track.gd")
const Obstacles=preload("res://src/obstacles.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func fresh()->RefCounted:
	var race:=Race.new([{"slot":0}],31,1,"hard","forest")
	race.countdown=0.;race.clock=5.
	return race
func approach(race:RefCounted,height:float,descent:float,roll:float=0.,item:String="")->Dictionary:
	var p:Dictionary=race.racers[0]
	p.distance=500.;p.x=0.;p.energy=100.;p.airborne=true;p.air_time=.5;p.air_travel=0.
	p.crashed=false;p.recovery=0.;p.wreck_wait=false;p.weapon=item;p.landing_assist=0.;p.landing_fx=0.
	var n:Dictionary=race.track.sample(p.distance)
	p.air_frame=n.frame*Basis(Vector3.BACK,roll)
	p.air_position=Track.point(n,0.,Flight.HOVER+height)
	p.air_velocity=n.frame.z*200.-n.frame.y*descent
	p.air_rates=Vector3.ZERO;p.trim=0.;p.speed=p.air_velocity.length()
	return p
func _initialize()->void: call_deferred("run")
func run()->void:
	var base:=Basis.IDENTITY
	check(Flight.touchdown_damage(base,base,Vector3(0,-5,250))==0.,"Clean touchdown at racing speed causes no damage")
	var soft:=Flight.touchdown_damage(base,base,Vector3(0,-20,200))
	var hard:=Flight.touchdown_damage(base,base,Vector3(0,-65,200))
	check(hard>soft and soft>0.,"Damage rises with normal impact speed")
	check(Flight.touchdown_damage(base*Basis(Vector3.BACK,.55),base,Vector3(0,-20,200))>soft+1.,"Tilted wings add mild damage")
	check(Flight.touchdown_damage(base*Basis(Vector3.UP,.55),base,Vector3(0,-20,200))>soft+1.,"Yaw misalignment adds mild damage")
	check(Flight.touchdown_damage(base,base,Vector3(55,-20,200))>soft+1.,"Sideways sliding adds mild damage")
	check(Flight.touchdown_damage(base*Basis(Vector3.BACK,deg_to_rad(10.)),base,Vector3(10,-16,250))==0.,"Ordinary small landing imperfections are forgiven")
	check(hard<5. and Flight.touchdown_damage(base,base,Vector3(0,-400,200))<=18.,"Landing damage is substantially reduced and capped")
	var bank:=Basis(Vector3.FORWARD,2.6)
	check(is_equal_approx(Flight.touchdown_damage(bank,bank,bank*Vector3(0,-20,200)),soft),"Banked and inverted tracks use their local deck frame")
	var race:=fresh()
	var p:=approach(race,.2,55.,.35)
	Flight.step(p,race.track,.01,0.,0.,0.,0.)
	check(not p.airborne and not p.crashed and p.energy>94. and p.landing_damage>2.,"Typical rough landing only costs a few shield points")
	check(p.shield_hit>0. and p.flash>0.,"Impact produces visible damage feedback")
	p=approach(race,.2,90.,.9)
	Flight.step(p,race.track,.01,0.,0.,0.,0.)
	check(not p.airborne and not p.crashed and p.energy>82.,"Recoverable steep tilted touchdown no longer triggers an abrupt wreck")
	p=approach(race,.2,55.,.35);p.energy=2.
	Flight.step(p,race.track,.01,0.,0.,0.,0.)
	check(p.crashed and p.wreck_wait and p.energy==0.,"Fatal landing becomes a wreck before automatic recovery")
	for dt in [1./30.,1./60.,1./120.]:
		race=fresh();p=approach(race,12.,65.,1.6,"landing")
		Flight.step(p,race.track,dt,1.,1.,0.,1.)
		check(p.weapon.is_empty() and p.landing_assist>0. and p.airborne,"Assist engages above deck and consumes once, dt=%s"%dt)
		check(p.landing_fx>0. and p.air_frame.y.dot(race.track.sample(500.).frame.y)>cos(1.6),"Guidance visibly levels the vehicle before contact")
		for tick in range(90):
			if not p.airborne: break
			Flight.step(p,race.track,dt,1.,1.,0.,1.)
		check(not p.airborne and not p.crashed and p.energy==100. and p.landing_damage==0.,"Assist gives a perfect landing despite held sticks, dt=%s"%dt)
		check(is_zero_approx(p.heading) and absf(p.slip)<.001 and p.landing_assist==0.,"Guidance hands back stable control and expires")
	# Swept contact can reach a new deck between frames; still protect that touchdown.
	race=fresh();p=approach(race,.2,140.,PI,"landing")
	Flight.step(p,race.track,.01,0.,0.,0.,0.)
	for tick in range(120):
		if not p.airborne: break
		Flight.step(p,race.track,.01,0.,0.,0.,0.)
	check(not p.crashed and not p.airborne and p.energy==100.,"Assist rescues a very steep inverted top-side impact")
	p=approach(race,.2,55.,.35)
	Flight.step(p,race.track,.01,0.,0.,0.,0.)
	check(p.energy<100.,"Next unassisted landing can damage the plane again")
	race=fresh();p=approach(race,100.,10.,0.,"landing")
	Flight.step(p,race.track,.01,0.,0.,0.,0.)
	check(p.weapon=="landing" and p.landing_assist==0.,"Does not engage high above the track")
	check(not race.weapons.activate(race,0) and p.weapon=="landing","X does not waste an automatic pickup")
	p=approach(race,8.,65.,0.,"landing")
	var n:Dictionary=race.track.sample(500.)
	p.air_position=Track.point(n,n.width+30.,9.3)
	Flight.step(p,race.track,.02,0.,0.,0.,0.)
	check(p.weapon=="landing" and p.landing_assist==0.,"Missing the deck never teleports the craft onto it")
	p=approach(race,-4.,-100.,0.,"landing")
	Flight.step(p,race.track,.05,0.,0.,0.,0.)
	check(p.crashed and p.landing_assist==0.,"Assist cannot land through the underside")
	race=fresh();p=approach(race,12.,65.,.4,"landing")
	n=race.track.sample(500.)
	race.track.obstacles=Obstacles.new()
	race.track.obstacles.add_box(Transform3D(n.frame.scaled(Vector3(30.,30.,1.)),p.air_position+n.frame.z*8.))
	Flight.step(p,race.track,.05,0.,0.,0.,0.)
	check(p.crashed and p.landing_assist==0.,"Active guidance still collides with buildings and objects")
	race=fresh();p=approach(race,3.,65.,0.,"landing")
	var jump:Dictionary=race.track.jumps[0]
	p.distance=(jump.takeoff+jump.landing)*.5
	n=race.track.sample(p.distance)
	p.air_position=Track.point(n,0.,4.3);p.air_frame=n.frame;p.air_velocity=n.frame.z*200.-n.frame.y*65.
	Flight.step(p,race.track,.01,0.,0.,0.,0.)
	check(p.weapon=="landing" and p.landing_assist==0. and p.airborne,"Missing-deck sections cannot trigger guidance")
	race=fresh();p=approach(race,.2,55.,.35);p.energy=2.
	race.step(.01,[{}]);race.step(.01,[{"reset":true}])
	for tick in range(250): race.step(.01,[{}])
	check(not p.crashed and p.energy==25.,"Lethal touchdown can recover with the small shield reserve")
	var draws:=0
	for i in range(6000):
		if race.weapons.choose(3,6)=="landing": draws+=1
	check(draws>900 and draws<1300,"Landing assist appears in pickup rolls at approximately 18 percent")
	print("LANDING_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
