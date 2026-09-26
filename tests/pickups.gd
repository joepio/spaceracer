extends SceneTree
const Race=preload("res://src/race.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func cross(race:RefCounted,index:int,pickup:Dictionary)->void:
	var p:Dictionary=race.racers[index]
	p.weapon_before=pickup.distance-20.;p.distance=pickup.distance+20.
	p.weapon_x_before=pickup.x;p.x=pickup.x
	race.weapons.collect(race,p)
func _initialize()->void: call_deferred("run")
func run()->void:
	for seed_value in [6,31,145,421]:
		var race:=Race.new([{"slot":2},{"slot":7},{"slot":11}],seed_value,3,"hard","forest")
		race.countdown=0.;race.clock=5.
		var original_rows:=0;var distance:=360.
		while distance<race.track.length-250.:
			var n:Dictionary=race.track.sample(distance)
			if not n.loop and not n.air_gap and n.split_gap<.01 and n.feature=="ribbon" and absf(n.curve)<.007 and race.track.jump_at(distance,220.).is_empty():
				original_rows+=1;distance+=760.
			else: distance+=35.
		check(race.weapons.pickups.size()==ceili(original_rows/3.)*3,"Keep exactly one in three former stations, seed %d"%seed_value)
		var row:Dictionary=race.weapons.pickups[1]
		cross(race,0,row)
		check(not race.racers[0].weapon.is_empty() and row.cooldown==2. and row.reveal==0.,"Collection immediately hides this pickup")
		check(race.racers[0].pickup_fx==.45 and race.racers[0].pickup_pose==row.pose,"Collector and track get a shared-world flash event")
		cross(race,1,row)
		check(race.racers[1].weapon.is_empty(),"Another player cannot collect the invisible pickup")
		cross(race,1,race.weapons.pickups[0])
		check(not race.racers[1].weapon.is_empty(),"The adjacent lane remains available")
		race.weapons.begin_step(race,1.99,[{},{},{}]);cross(race,2,row)
		check(race.racers[2].weapon.is_empty() and row.cooldown>0.,"Pickup stays unavailable for the full two seconds")
		race.weapons.begin_step(race,.02,[{},{},{}]);cross(race,2,row)
		check(not race.racers[2].weapon.is_empty(),"Pickup reappears and becomes collectible after two seconds")
		race.weapons.begin_step(race,2.2,[{},{},{}])
		check(row.cooldown==0. and row.reveal==1. and race.racers[0].pickup_fx==0.,"Respawn animation completes and flash expires")
		race.racers[0].weapon="";cross(race,0,row)
		check(race.racers[0].weapon.is_empty(),"Respawn does not allow reverse farming in the same lap")
	print("PICKUP_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
