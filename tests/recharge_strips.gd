extends SceneTree
const Race=preload("res://src/race.gd")
const Track=preload("res://src/track.gd")
const Recharge=preload("res://src/recharge_strips.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	for seed_value in [1,6,31,32,33,34,35,36,145,421,80385,99999]:
		for difficulty in Track.DIFFICULTIES:
			for biome in Track.BIOMES:
				var track:=Track.new(seed_value,difficulty,biome)
				check(track.recharge_strips.size()>=2 and track.recharge_strips.size()<=3,"Every sampled recipe has 2–3 recharge strips: %d %s %s"%[seed_value,difficulty,biome])
				for strip in track.recharge_strips:
					check(strip.end-strip.start>=160.,"Recharge has a useful length at racing speed")
					for index in range(roundi(strip.start/track.step),roundi(strip.end/track.step)):
						var n:Dictionary=track.nodes[index]
						check(Recharge.eligible(track,index) and n.rails and n.zone=="repair","Charging stays on gentle supported road with guardrails")
	var first:=Track.new(80385,"hard");var repeat:=Track.new(80385,"hard")
	check(first.recharge_strips==repeat.recharge_strips,"Seed reproduces strip placement")
	for hz in [30,60,120]:
		var race:=Race.new([{"slot":0},{"slot":1}],31);race.countdown=0.
		for i in range(2):
			var p:Dictionary=race.racers[i];p.distance=race.track.recharge_strips[0].start+40.+i*40.
			p.x=race.track.sample(p.distance).width*Recharge.CENTER;p.energy=10.;p.energy_previous=10.;p.weapon="railgun"
		for tick in range(hz): race.step(1./hz,[{"brake":1.},{"brake":1.}])
		for p in race.racers:
			check(absf(p.energy-44.)<.01,"Both players charge at full rate, without consuming shared supply")
			check(p.weapon=="railgun" and p.energy_fx>0.,"Charging gives feedback without changing inventory")
		for tick in range(hz*3): race.step(1./hz,[{"brake":1.},{"brake":1.}])
		check(race.racers.all(func(p):return p.energy==100.),"Waiting on a strip can refill all the way: no per-pass cap")
		var pilot:Dictionary=race.racers[0];pilot.energy=20.;pilot.energy_previous=20.
		for tick in range(hz): race.step(1./hz,[{"brake":1.},{"brake":1.}])
		check(pilot.energy>53.9,"Strip can recharge again without a cooldown or a new lap")
	var race:=Race.new([{"slot":0}],31)
	var p:Dictionary=race.racers[0];var n:Dictionary=race.track.sample(race.track.recharge_strips[0].center)
	p.x=n.width*Recharge.CENTER
	for field in ["airborne","crashed","finished","recovery","warp_time"]:
		p.energy=10.;p[field]=true if field in ["airborne","crashed","finished"] else 1.
		Recharge.apply(p,n,1.);check(p.energy==10.,"No strip charging during "+field)
		p[field]=false if field in ["airborne","crashed","finished"] else 0.
	p.x=n.width*.6;Recharge.apply(p,n,1.);check(p.energy==10.,"Outside the marked lane does not charge")
	p.x=n.width*Recharge.CENTER;p.lift=2.;Recharge.apply(p,n,1.);check(p.energy==10.,"Lifting off breaks contact with the strip")
	p.lift=0.;p.distance=race.track.recharge_strips[0].center
	race.step(1.,[{}]);check(p.energy==10.,"Countdown cannot farm starting energy")
	print("RECHARGE_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
