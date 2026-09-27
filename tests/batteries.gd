extends SceneTree
const Race=preload("res://src/race.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func cross(race:RefCounted,p:Dictionary,battery:Dictionary,lap:int=0)->void:
	p.weapon_before=battery.distance+race.track.length*lap-20.;p.distance=p.weapon_before+40.
	p.weapon_x_before=battery.x;p.x=battery.x
	race.weapons.collect_energy(race,p)
func _initialize()->void: call_deferred("run")
func run()->void:
	for biome in ["city","forest"]:
		for seed_value in [6,31,145,421]:
			var race:=Race.new([{"slot":2},{"slot":7}],seed_value,3,"hard",biome)
			race.countdown=0.;race.clock=5.
			check(not race.weapons.batteries.is_empty(),"Battery stations exist on seeded "+biome)
			var repeat:=Race.new([{"slot":2}],seed_value,3,"hard",biome)
			check(race.weapons.batteries==repeat.weapons.batteries,"Battery placements reproduce from seed")
			for battery in race.weapons.batteries:
				if battery.get("air",false): continue
				var n:Dictionary=race.track.sample(battery.distance)
				check(Race.Track.supported(n,battery.x,5.8) and not n.loop and race.track.jump_at(battery.distance,220.).is_empty(),"Batteries sit on safe supported road away from jump lips")
				check(race.weapons.pickups.all(func(item):return absf(item.distance-battery.distance)>100.),"Batteries and weapon stations remain separated")
			var b:Dictionary=race.weapons.batteries[1]
			var p:Dictionary=race.racers[0];var rival:Dictionary=race.racers[1]
			p.energy=40.;p.weapon="missile";var rng_state:int=race.weapons.rng.state
			cross(race,p,b)
			check(p.energy==65. and p.weapon=="missile" and rng_state==race.weapons.rng.state,"Battery adds 25 immediately without replacing a weapon or rerolling items")
			check(b.cooldown==2. and b.reveal==0. and p.pickup_energy and p.energy_fx>0. and p.energy_gained==25.,"Collection hides battery and triggers shared flash and energy feedback")
			rival.energy=95.;cross(race,rival,b)
			check(rival.energy==95.,"Other players cannot collect the hidden battery")
			race.weapons.begin_step(race,2.01,[{},{}]);cross(race,rival,b)
			check(rival.energy==100. and rival.energy_gained==5.,"After respawn another player collects, capped at 100")
			race.weapons.begin_step(race,2.1,[{},{}]);p.energy=40.;cross(race,p,b)
			check(p.energy==40.,"Returning to the same station cannot farm energy within a lap")
			cross(race,p,b,1)
			check(p.energy==65.,"Same player can collect again next lap")
	var race:=Race.new([{"slot":0}],31);race.countdown=0.
	var p:Dictionary=race.racers[0];var b:Dictionary=race.weapons.batteries[1]
	cross(race,p,b)
	check(b.cooldown==0. and b.claimed.is_empty(),"Full-energy players leave batteries for rivals")
	p.energy=5.
	for state in ["airborne","crashed","finished","recovery","warp_time","warp_fx"]:
		p[state]=true if state in ["airborne","crashed","finished"] else 1.
		cross(race,p,b)
		check(p.energy==5. and b.cooldown==0.,"No collection while "+state)
		p[state]=false if state in ["airborne","crashed","finished"] else 0.
	p.weapon_before=b.distance+10.;p.distance=b.distance-10.;race.weapons.collect_energy(race,p)
	check(p.energy==5.,"Reverse crossing does not collect")
	p.weapon_before=b.distance-200.;p.distance=b.distance+1.;race.weapons.collect_energy(race,p)
	check(p.energy==5.,"Respawn or teleport cannot sweep batteries")
	p.distance=b.distance-1.+race.track.length;p.x=b.x;p.speed=235.;p.lap=2;p.weapon="drone"
	race.step(.01,[{"throttle":1.}])
	check(p.energy==30. and p.weapon=="drone","Live physics crosses battery at speed while carrying an item")
	race.step(.01,[{"boost":true,"throttle":1.}])
	check(p.boost>1. and p.energy==8.,"Collected energy can immediately fund a boost")
	print("BATTERY_TESTS %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
