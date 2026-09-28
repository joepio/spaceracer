extends SceneTree
const Race=preload("res://src/race.gd")
const Flight=preload("res://src/flight.gd")
const Track=preload("res://src/track.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func fresh()->RefCounted:
	var race:=Race.new([{"slot":2},{"slot":7},{"slot":11},{"slot":13}],31,3,"hard","forest")
	race.countdown=0.;race.clock=5.
	for i in range(4):
		var p:Dictionary=race.racers[i]
		p.distance=500.+[0.,70.,-60.,400.][i];p.speed=200.;p.startup=1.;p.engine_power=1.;p.thrust=1.
		race.racers[0].weapon="emp"
	return race
func _initialize()->void: call_deferred("run")
func run()->void:
	var race:=fresh();var owner:Dictionary=race.racers[0];var target:Dictionary=race.racers[1]
	check(race.weapons.activate(race,0) and owner.weapon.is_empty(),"EMP consumes inventory")
	race.weapons.step_emp(race,.05)
	check(target.emp_time>0.,"Map-wide EMP applies on the first update")
	race.weapons.step_emp(race,.25)
	check(target.emp_time>0. and race.racers[2].emp_time>0.,"Pulse disables rivals ahead and behind, regardless of seat IDs")
	check(owner.emp_time==0. and owner.engine_power==1.,"Emitter engines remain powered")
	check(race.racers[3].emp_time>0.,"Ships outside the visual sphere also lose their engines")
	check(target.engine_power==0. and target.thrust==0. and target.energy==100. and target.speed==200.,"Shutdown stops thrust and exhaust without damage or an instant speed change")
	var duration:float=target.emp_time
	race.weapons.begin_step(race,.1,[{},{},{},{}]);race.weapons.step_emp(race,.1)
	check(target.emp_time<duration,"One expanding pulse cannot repeatedly reset the shutdown timer")
	var before:float=target.speed
	race.step(.1,[{"throttle":1.},{"throttle":1.,"boost":true},{},{}])
	check(target.speed<before and target.thrust==0. and target.engine_power==0.,"Full throttle cannot defeat a shutdown")
	check(target.boost==0. and target.energy==100.,"Boost input is blocked without spending shields")
	for tick in range(240): race.step(.01,[{"throttle":1.},{"throttle":1.},{},{}])
	check(target.emp_time==0. and target.thrust>0. and target.engine_power>.5,"Held throttle automatically restarts after EMP expires")
	check(race.weapons.pulses.is_empty(),"Expired pulse is removed")
	race=fresh();target=race.racers[1]
	target.airborne=true;target.air_frame=Basis.IDENTITY
	target.air_position=race.weapons.pose(race,race.racers[0]).origin+Vector3.UP*80.
	race.racers[2].airborne=true;race.racers[2].air_frame=Basis.IDENTITY
	race.racers[2].air_position=target.air_position+Vector3(50000,30000,-40000)
	race.weapons.activate(race,0);race.weapons.step_emp(race,.4)
	check(target.emp_time>0. and race.racers[2].emp_time>0.,"EMP reaches airborne rivals anywhere on the map, including extreme altitude")
	race=fresh();target=race.racers[1]
	target.weapon_guard=2.;race.weapons.activate(race,0);race.weapons.step_emp(race,.4)
	check(target.emp_time==0.,"Recent respawn protection prevents immediate shutdown")
	race=fresh();target=race.racers[1]
	target.emp_guard=1.;race.weapons.activate(race,0);race.weapons.step_emp(race,.4)
	check(target.emp_time==0.,"Reboot protection prevents an EMP chain lock")
	race=fresh();target=race.racers[1];target.weapon="warp"
	race.weapons.activate(race,1);race.weapons.activate(race,0);race.weapons.step_emp(race,.4)
	check(target.warp_time==0. and target.emp_time>0.,"EMP interrupts warp propulsion")
	target.weapon="warp"
	check(not race.weapons.activate(race,1) and target.weapon=="warp","Disabled warp cannot reactivate or waste inventory")
	race=fresh();target=race.racers[1]
	var jump:Dictionary=race.track.jumps[0]
	target.distance=(jump.takeoff+jump.landing)*.5
	race.racers[0].distance=target.distance-30.;target.warp_time=1.
	var n:Dictionary=race.track.sample(target.distance);target.ground_velocity=n.frame.z*400.
	race.weapons.activate(race,0);race.weapons.step_emp(race,.4)
	check(target.airborne and not target.crashed and target.air_velocity.length()>390.,"Interrupted warp over a gap carries momentum into real flight")
	var powered:Dictionary=target.duplicate(true);powered.emp_time=0.
	Flight.integrate_air(target,.05,.5,.5,1.,0.)
	Flight.integrate_air(powered,.05,.5,.5,1.,0.)
	check(target.air_velocity.distance_to(powered.air_velocity)>1. and target.air_rates.length()>0.,"Airborne EMP cuts engine force while keeping aerodynamic controls")
	Flight.crash(target)
	check(target.emp_time==0.,"Crash clears disabled-engine state")
	race=fresh();race.countdown=.1
	race.step(.1,[{"fire":true},{},{},{}]);race.step(.01,[{"fire":true},{},{},{}])
	check(race.weapons.pulses.is_empty(),"Countdown cannot prefire EMP")
	race.step(.01,[{},{},{},{}]);race.step(.01,[{"fire":true},{},{},{}])
	check(race.weapons.pulses.size()==1,"Fresh X press activates through race input")
	# EMP intercepts live ordnance everywhere during the active pulse.
	race=fresh();race.racers[2].weapon="missile"
	check(race.weapons.activate(race,2),"Missile fixture launches")
	var missile:Dictionary=race.weapons.missiles[0]
	var center:Vector3=race.weapons.pose(race,race.racers[0]).origin
	missile.position=center+Vector3.UP*40.
	race.weapons.activate(race,0);race.weapons.step_emp(race,.2)
	check(missile.disabled and is_inf(race.Weapons.missile_eta(race,missile)),"EMP disables missile guidance and warning")
	var velocity:Vector3=missile.velocity
	race.weapons.step_missile(race,missile,.1)
	check(missile.velocity.y<velocity.y and race.weapons.bursts.is_empty(),"Disabled missile falls harmlessly without an explosion")
	for tick in range(12): race.weapons.step_missile(race,missile,.1)
	check(race.weapons.missiles.is_empty(),"Disabled missiles are cleaned up")
	race.racers[1].weapon="missile";race.racers[1].emp_time=1.
	check(not race.weapons.activate(race,1) and race.racers[1].weapon=="missile","Shutdown blocks launch without consuming inventory")
	var far:Dictionary={"disabled":false}
	check(race.weapons.intercept_missile(far,center+Vector3.UP*30000.,center+Vector3.UP*40000.),"Distant missiles are disabled globally")
	var crossing:Dictionary={"disabled":false}
	check(race.weapons.intercept_missile(crossing,center-Vector3.RIGHT*300.,center+Vector3.RIGHT*300.),"Fast missiles are disabled regardless of trajectory")
	race.weapons.step_emp(race,.5)
	var edge:Dictionary={"disabled":false}
	check(race.weapons.intercept_missile(edge,center+Vector3.UP*219.,center+Vector3.UP*219.),"Global missile shutdown lasts through the active pulse")
	race.weapons.step_emp(race,.1)
	check(not race.weapons.intercept_missile({"disabled":false},center,center),"Lingering pulse visual cannot intercept new missiles")
	var rolls:=0
	for i in range(6000):
		if race.weapons.choose(3,6)=="emp": rolls+=1
	check(rolls>800 and rolls<1150,"EMP appears in normal pickup rolls")
	print("EMP_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
