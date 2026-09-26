extends SceneTree
## Exercise flight with the shipped world's scenery/fixture collision field.
const Race=preload("res://src/race.gd")
const World=preload("res://src/world.gd")
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	for biome in ["forest","city"]:
		for difficulty in ["normal","hard"]:
			var roster:Array=[]
			for slot in range(6): roster.append({"slot":slot,"bot":true})
			var race:=Race.new(roster,31,1,difficulty,biome)
			var world:=World.new();root.add_child(world);world.build(race)
			check(not race.track.obstacles.shapes.is_empty(),"Full world includes actual obstacle collision")
			for jump in race.track.jumps:
				var launched:={};var landed:={}
				# Fresh pilots for each jump, in a normal three-wide pack.
				race.racers=Race.new(roster,31,1,difficulty,biome).racers
				race.countdown=0.;race.clock=0.;race.over=false
				for p in race.racers:
					p.distance=jump.takeoff-180.-floorf(p.slot/3.)*13.;p.speed=250.
				for tick in range(120*12):
					world.scenery.animate(race.clock)
					var inputs:Array=[]
					for p in race.racers:
						inputs.append({} if landed.has(p.slot) or p.crashed else race.bot(p))
					race.step(1./120.,inputs)
					for p in race.racers:
						if p.airborne: launched[p.slot]=true
						if launched.has(p.slot) and not p.airborne and not landed.has(p.slot):
							landed[p.slot]=not p.crashed and p.distance>=jump.landing
							# Keep completed pilots out of later contacts and obstacles.
							p.finished=true
					if landed.size()==6: break
				for p in race.racers:
					check(landed.get(p.slot,false),"%s %s seed 31 %s pilot %d lands with world collisions enabled"%[biome,difficulty,jump.kind,p.slot])
				print("WORLD_JUMP ",biome," ",difficulty," ",jump.kind," results=",landed)
			world.free()
			await process_frame
	print("WORLD_JUMP_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
