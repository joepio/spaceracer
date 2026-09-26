extends SceneTree
const Race=preload("res://src/race.gd")
const Obstacles=preload("res://src/obstacles.gd")
const Bridge=preload("res://src/bridge.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func fresh(laps:int=3)->RefCounted:
	var race:=Race.new([{"slot":2},{"slot":7},{"slot":11}],31,laps,"hard","forest")
	race.countdown=0.;race.clock=5.
	for i in range(3):
		var p:Dictionary=race.racers[i]
		p.distance=700.-i*90.;p.x=0.;p.speed=200.;p.startup=1.;p.ignited=true
	return race
func neutral()->Array: return [{},{},{}]
func _initialize()->void: call_deferred("run")
func run()->void:
	var race:=fresh()
	check(race.weapons.pickups.size()>=3 and race.weapons.pickups.size()<=12,"Track retains a sparse set of usable pickup rows")
	check(race.weapons.pickups==fresh().weapons.pickups,"Pickup layout is reproducible by seed")
	var fronts:=0;var backs:=0
	for i in range(6000):
		if race.weapons.choose(1,6) in ["missile","warp"]: fronts+=1
		if race.weapons.choose(6,6) in ["missile","warp"]: backs+=1
	check(backs>fronts*1.25 and fronts>500,"Catch-up odds favor the rear while useful items remain available up front")
	for count in [1,2,6]:
		var leader_warps:=0
		for i in range(6000):
			if race.weapons.choose(1,count,2000.)=="warp": leader_warps+=1
		check(leader_warps==0,"Leader never rolls warp, even with an inconsistent gap, racers=%d"%count)
	for count in [2,6]:
		var close_warps:=0;var distant_warps:=0
		race.weapons.rng.seed=1234
		for i in range(6000):
			if race.weapons.choose(count,count,50.)=="warp": close_warps+=1
		race.weapons.rng.seed=1234
		for i in range(6000):
			if race.weapons.choose(count,count,1800.)=="warp": distant_warps+=1
		check(close_warps>600 and close_warps<1100 and distant_warps>2300 and distant_warps<2750,"Warp is substantially more likely far behind, racers=%d"%count)
	for rank in range(1,7):
		for gap in [0.,150.,500.,1500.,10000.]:
			var odds:Vector3=race.Weapons.weights(rank,6,gap)
			check(odds.x>=0. and odds.y>=0. and odds.z>=0. and is_equal_approx(odds.x+odds.y+odds.z,1.),"Item weights stay normalized")
	var row:Dictionary=race.weapons.pickups[1]
	for p in race.racers:
		race.weapons.begin_step(race,2.01,neutral())
		p.weapon_before=row.distance-30.;p.weapon_x_before=row.x;p.distance=row.distance+30.;p.x=row.x
		race.weapons.collect(race,p)
		check(not p.weapon.is_empty(),"Swept pickup collects at speed for each player, including sparse seat IDs")
		if race.standings()[0]==p: check(p.weapon!="warp","Actual first-place collector cannot receive warp")
		p.weapon="";race.weapons.collect(race,p)
		check(p.weapon.is_empty(),"Backing through a used row cannot farm it")
		race.weapons.begin_step(race,2.01,neutral())
		p.weapon_before=row.distance-30.
		p.weapon_before+=race.track.length;p.distance+=race.track.length
		race.weapons.collect(race,p)
		check(not p.weapon.is_empty(),"Pickup recharges on the following lap")
	race=fresh()
	var chaser:Dictionary=race.racers[1]
	row=race.weapons.pickups[1]
	chaser.distance=race.track.length+row.distance+10.;chaser.weapon_before=chaser.distance-20.
	chaser.x=row.x;chaser.weapon_x_before=row.x
	race.racers[0].distance=chaser.distance+2000.
	# Choose a seed whose result distinguishes the real gap from rank alone.
	var discriminating_seed:=false
	for seed_value in range(100):
		race.weapons.rng.seed=seed_value
		var distant:String=race.weapons.choose(2,race.racers.size(),2000.)
		race.weapons.rng.seed=seed_value
		var nearby:String=race.weapons.choose(2,race.racers.size(),0.)
		if distant=="warp" and nearby!="warp":
			race.weapons.rng.seed=seed_value;discriminating_seed=true;break
	race.weapons.collect(race,chaser)
	check(discriminating_seed and chaser.weapon=="warp","Collection uses actual unwrapped leader gap across laps")
	race=fresh()
	var owner:Dictionary=race.racers[2];var leader:Dictionary=race.racers[0]
	owner.weapon="missile"
	check(race.weapons.activate(race,2),"Missile launches from the rear")
	check(race.weapons.missiles[0].target==0 and owner.weapon.is_empty(),"Cruise missile consumes inventory and auto-targets the actual leader")
	for tick in range(300):
		race.clock+=.01
		for m in race.weapons.missiles.duplicate(): race.weapons.step_missile(race,m,.01)
	check(leader.energy==62. and leader.speed<140.,"Undodged missile hits shields and slows its target")
	check(not race.weapons.damage(race,leader,38.,.66),"Brief protection prevents stacked missile damage")
	for late in [true,false]:
		race=fresh();owner=race.racers[2];leader=race.racers[0];owner.weapon="missile"
		race.weapons.activate(race,2)
		var missile:Dictionary=race.weapons.missiles[0];missile.terminal=.20
		missile.position=race.Weapons.pose(race,leader).origin-Vector3(0,0,25.)
		race.weapons.begin_step(race,.01,neutral())
		leader.weapon_velocity=Vector3(0,0,250.);leader.ground_velocity=Vector3(200.,0,150.)
		leader.input_steer=1.;leader.slide=1.;leader.jinking=not late;leader.last_jink=race.clock-1.
		race.weapons.end_step(race,.01)
		check(missile.evaded==late,"A fresh late high-G jink evades; an early sustained turn does not")
		if late: check(leader.evade_notice>0. and leader.energy==100.,"Successful dodge is acknowledged and prevents damage")
	race=fresh();leader=race.racers[0];owner=race.racers[2]
	leader.distance=race.weapons.pickups[1].distance;leader.speed=300.;leader.x=0.
	leader.ground_velocity=race.track.sample(leader.distance).frame.z*300.
	race.racers[1].distance=leader.distance-60.
	owner.distance=leader.distance-100.;owner.weapon="missile";race.weapons.activate(race,2)
	var physical_missile:Dictionary=race.weapons.missiles[0];physical_missile.terminal=.22
	physical_missile.position=race.Weapons.pose(race,leader).origin-race.track.sample(leader.distance).frame.z*40.
	for tick in range(24):
		race.step(.01,[{"throttle":1.,"steer":1.,"brake":1.},{},{}])
	check(physical_missile.evaded and leader.energy==100.,"Actual late steering/braking physics can evade, without synthetic G-force state")
	race=fresh();owner=race.racers[2];owner.weapon="warp"
	var distance:float=owner.distance
	check(race.weapons.activate(race,2),"Warp activates on the track")
	for tick in range(400):
		race.step(.01,neutral())
		if owner.warp_time<=0.: break
	check(owner.distance-distance>1000.,"Warp drives forward for a few seconds and gains ground")
	check(not owner.airborne and not owner.crashed and owner.speed<=280.,"Warp returns stable control near normal speed")
	check(owner.energy==100.,"Warp does not spend ordinary shield/boost energy")
	race=fresh();owner=race.racers[2];owner.lap=2;owner.distance=race.track.length+700.;owner.weapon="warp"
	race.weapons.activate(race,2)
	race.step(.01,[{},{},{"boost":true,"brake":1.,"steer":1.,"trim":-1.}])
	check(owner.energy==100. and owner.heading==0. and owner.boost==0.,"Autopilot ignores manual driving and boost expenditure")
	for jump in race.track.jumps:
		race=fresh();owner=race.racers[2];owner.distance=jump.takeoff-60.;owner.weapon="warp"
		race.weapons.activate(race,2)
		for tick in range(700):
			race.step(.01,neutral())
			if owner.warp_time<=0.: break
		check(not owner.crashed and not owner.airborne and not race.track.sample(owner.distance).air_gap,"Warp crosses difficult flight gaps and releases over supported deck")
	race=fresh(1);owner=race.racers[2];owner.distance=race.track.length-50.;owner.weapon="warp"
	race.weapons.activate(race,2)
	for tick in range(100):
		race.step(.01,neutral())
		if owner.finished: break
	check(owner.finished and owner.lap==2 and owner.time<INF,"Warp crossing the finish records a legitimate lap and time")
	race=fresh();owner=race.racers[2];owner.weapon="drone"
	check(race.weapons.activate(race,2),"Drone deploys")
	race.weapons.begin_step(race,.01,neutral())
	check(race.weapons.drone_target(race,2)==1,"Drone chooses the nearest rival ahead instead of always choosing the leader")
	for tick in range(810): race.weapons.end_step(race,.01)
	check(race.racers[1].energy<50. and race.racers[0].energy==100. and owner.energy==100.,"Sentry deals repeated shield damage only to its selected rival")
	check(owner.drone_time==0.,"Drone expires instead of providing permanent firepower")
	race=fresh();owner=race.racers[2];owner.weapon="drone";race.weapons.activate(race,2)
	race.weapons.begin_step(race,.01,neutral())
	var from:=Race.Weapons.drone_position(race,owner)
	var to:=Race.Weapons.pose(race,race.racers[1]).origin
	race.track.obstacles=Obstacles.new()
	race.track.obstacles.add_box(Transform3D(Basis.IDENTITY,(from+to)*.5),AABB(Vector3.ONE*-8.,Vector3.ONE*16.))
	for tick in range(100): race.weapons.end_step(race,.01)
	check(race.racers[1].energy==100.,"Scenery blocks drone gunfire")
	race=fresh();owner=race.racers[2];owner.weapon="drone";race.countdown=.1
	race.step(.1,[{},{},{"fire":true}]);race.step(.01,[{},{},{"fire":true}])
	check(owner.drone_time==0. and owner.weapon=="drone","Holding use during countdown cannot fire when the race opens")
	race.step(.01,neutral());race.step(.01,[{},{},{"fire":true}])
	check(owner.drone_time>0. and owner.weapon.is_empty(),"Fresh use press fires after countdown")
	owner.weapon="warp";owner.airborne=true;owner.drone_time=0.
	check(not race.weapons.activate(race,2) and owner.weapon=="warp","Warp cannot rescue an off-track flight by teleporting to the road")
	owner.airborne=false;owner.energy=3.
	race.weapons.damage(race,owner,4.,1.)
	check(owner.crashed and owner.wreck_wait and owner.recovery==0.,"Shield depletion uses normal crash and automatic recovery")
	race.weapons.begin_step(race,.01,neutral())
	check(owner.weapon.is_empty() and owner.drone_time==0. and owner.warp_time==0.,"Crashing clears carried and active items")
	var bridge:=Bridge.new()
	bridge.frames={"ordinal:7":{"axes":[0,0,0,0,16384,0],"buttons":4}}
	bridge.frame_at=Time.get_ticks_msec()
	check(bridge.controls("ordinal:7").fire and bridge.controls("ordinal:7").brake>.45,"GameNight maps X to use and LT to brake independently")
	check(not bridge.controls("ordinal:2").fire,"Fire remains owned by the correct sparse controller token")
	bridge.frame_at-=1000
	check(not bridge.controls("ordinal:7").fire,"Stale network input cannot hold fire")
	bridge.free()
	print("WEAPON_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
