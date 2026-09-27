extends SceneTree
const Race=preload("res://src/race.gd")
var failures:=0
var finishers:=0
var expected:=0
func _initialize()->void: call_deferred("run")
func run()->void:
	for difficulty in ["easy","normal","hard"]:
		var args:=OS.get_cmdline_user_args()
		var selected_difficulty:=""
		var selected_seed:=0
		for arg in args:
			if arg.begins_with("--difficulty="): selected_difficulty=arg.get_slice("=",1)
			if arg.begins_with("--seed="): selected_seed=int(arg.get_slice("=",1))
		if selected_difficulty!="" and selected_difficulty!=difficulty: continue
		for seed_value in range(31,37):
			if selected_seed>0 and seed_value!=selected_seed: continue
			expected+=6
			var roster:Array=[]
			for slot in range(6): roster.append({"slot":slot,"bot":true})
			var race:=Race.new(roster,seed_value,3,difficulty)
			var launches:=0
			var warped_gaps:=0
			for tick in range(120*235):
				var inputs:Array=[]
				var was_air:Array=[]
				var was_gap:Array=[]
				for p in race.racers:
					inputs.append(race.bot(p));was_air.append(p.airborne)
					was_gap.append(race.track.sample(p.distance).air_gap)
				race.step(1./120.,inputs)
				for i in range(6):
					if race.racers[i].airborne and not was_air[i]: launches+=1
					var p:Dictionary=race.racers[i]
					if p.warp_time>0. and not was_gap[i] and race.track.sample(p.distance).air_gap: warped_gaps+=1
				if race.over: break
			var finished:int=race.racers.filter(func(p):return p.finished).size()
			finishers+=finished
			# Warp intentionally pilots over gaps without entering free flight.
			if finished!=6 or (difficulty=="easy" and launches>0) or (difficulty!="easy" and launches+warped_gaps<18):
				failures+=1
				push_error("Incomplete or incorrect difficulty race")
			print("DIFFICULTY_SOAK ",difficulty," ",seed_value," finishers=",finished,"/6 launches=",launches," warped_gaps=",warped_gaps," time=",race.clock)
	print("DIFFICULTY_SOAK_TOTAL ",finishers,"/",expected," finishers, ",failures," failures")
	quit(1 if failures else 0)
