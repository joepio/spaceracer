extends SceneTree
const Race=preload("res://src/race.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var multiplayer:bool="--race" in OS.get_cmdline_user_args()
	var beaten:=0
	for seed_value in [31,32,33,34,35,36]:
		var times:Array[float]=[]
		for simple in ([true] if multiplayer else [false,true]):
			var roster:Array=[]
			for slot in range(6 if multiplayer else 1): roster.append({"slot":slot,"bot":true})
			var race:=Race.new(roster,seed_value,3,"hard")
			var p:Dictionary=race.racers[0]
			var boosts:=0;var braking:=0.;var crashes:=0
			for tick in range(120*235):
				var controls:Dictionary=race.bot(p)
				controls.fire=false
				if simple and not p.airborne: controls.brake=0.;controls.boost=false;controls.trim=0.
				var previous_boost:float=p.boost;var previous_crash:int=p.crash_id
				var inputs:Array=[controls]
				for i in range(1,race.racers.size()): inputs.append(race.bot(race.racers[i]))
				race.step(1./120.,inputs)
				if p.boost>previous_boost: boosts+=1
				if p.crash_id>previous_crash: crashes+=1
				if p.input_brake>.05: braking+=1./120.
				if race.over: break
			times.append(p.time)
			# The steering-only baseline may DNF a hard hairpin; the full pilot must finish.
			if not simple:check(p.finished,"Benchmark pilot finishes seed %d"%seed_value)
			if not simple: check(boosts>=5,"Hard pilot spends boost during the race")
			if multiplayer and race.standings()[0]!=p: beaten+=1
			print("AI_PACE ",JSON.stringify({"seed":seed_value,"profile":race.track.layout,"simple":simple,"time":p.time if p.finished else 999.,"rank":p.rank,"boosts":boosts,"brake_seconds":braking,"crashes":crashes,"distance":p.distance,"finishers":race.racers.filter(func(pilot):return pilot.finished).size()}))
		if not multiplayer: check(times[0]<times[1]*.98,"Hard pilot beats steering-only pilot by at least 2 percent on seed %d"%seed_value)
	if multiplayer: check(beaten>=5,"Steering-only pilot loses at least five of six full races")
	print("AI_PACE_TESTS failures=",failures," full races beaten=",beaten)
	quit(1 if failures else 0)
