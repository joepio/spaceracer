extends SceneTree
const Race=preload("res://src/race.gd")
const Ship=preload("res://src/ship.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	for difficulty in ["easy","normal","hard"]:
		var race:=Race.new([{"slot":0,"bot":true}],35,3,difficulty)
		race.countdown=0.;race.clock=30.
		var p:Dictionary=race.racers[0];p.lap=2;p.ai_boost_lap=2;p.speed=250.;p.x=0.
		var found:=false
		for distance in range(0,int(race.track.length),20):
			p.distance=race.track.length+distance
			if race.bot(p).get("boost",false): found=true;break
		check(found,"Pilot finds a boost opportunity")
		var peak:float=p.speed;var braking:=0.
		for tick in range(120):
			var controls:Dictionary=race.bot(p);controls.fire=false
			race.step(1./120.,[controls])
			peak=maxf(peak,p.speed)
			if controls.get("brake",0.)>.05: braking+=1./120.
		print("AI_BOOST ",difficulty," peak_kmh=",peak*3.6," braking_seconds=",braking)
		check(peak>350.,"AI must actually accelerate toward boost speed on a straight")
	var delays:Array[float]=[]
	for repeat in range(2):
		var roster:Array=[]
		for slot in range(6): roster.append({"slot":slot,"bot":true})
		var race:=Race.new(roster,35,3,"normal");race.clock=40.
		for p in race.racers:
			p.lap=2;p.distance=race.track.length;p.speed=250.;p.x=0.
			check(not race.bot(p).boost,"AI waits after boost unlock instead of firing at the lap line")
			var delay:float=p.ai_boost_ready_at-race.clock
			if repeat==0: delays.append(delay)
			else: check(is_equal_approx(delay,delays[p.slot]),"Seeded pilot timing is reproducible")
			check(delay>=.15 and delay<=1.5,"Boost reaction delay is short and bounded")
	check(delays.max()-delays.min()>.5,"Pack boost decisions are staggered")
	var ship:=Ship.build(Color.CYAN)
	root.add_child(ship)
	var pilot:Dictionary=Race.new([{"slot":0}],35).racers[0]
	pilot.boost=1.;pilot.engine_power=1.;pilot.thrust=1.
	Ship.animate_effects(ship,pilot,0.,0.)
	check(ship.get_node("BoostArcs-1").visible,"Active boost shows powered exhaust")
	pilot.braking=.2
	Ship.animate_effects(ship,pilot,0.,0.)
	check(not ship.get_node("BoostArcs-1").visible,"Braking cannot show boost thrust that physics has canceled")
	ship.queue_free();await process_frame
	print("AI_BOOST_TESTS ",failures," failures")
	quit(1 if failures else 0)
