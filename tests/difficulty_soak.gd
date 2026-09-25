extends SceneTree
const Race=preload("res://src/race.gd")
var failures:=0
var finishers:=0
func _initialize()->void: call_deferred("run")
func run()->void:
	for difficulty in ["easy","normal","hard"]:
		for seed_value in [6,31,145,421]:
			var roster:Array=[]
			for slot in range(6): roster.append({"slot":slot,"bot":true})
			var race:=Race.new(roster,seed_value,3,difficulty)
			var launches:=0
			for tick in range(120*235):
				var inputs:Array=[]
				var was_air:Array=[]
				for p in race.racers: inputs.append(race.bot(p));was_air.append(p.airborne)
				race.step(1./120.,inputs)
				for i in range(6):
					if race.racers[i].airborne and not was_air[i]: launches+=1
				if race.over: break
			var finished:int=race.racers.filter(func(p):return p.finished).size()
			finishers+=finished
			if finished!=6 or (difficulty=="easy" and launches>0) or (difficulty!="easy" and launches<18):
				failures+=1
				push_error("Incomplete or incorrect difficulty race")
			print("DIFFICULTY_SOAK ",difficulty," ",seed_value," finishers=",finished,"/6 launches=",launches," time=",race.clock)
	print("DIFFICULTY_SOAK_TOTAL ",finishers,"/72 finishers, ",failures," failures")
	quit(1 if failures else 0)
