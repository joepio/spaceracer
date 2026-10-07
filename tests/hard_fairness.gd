extends SceneTree
const Race=preload("res://src/race.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	for seed_value in [33,80385]:
		for biome in ["city","forest","cell","desert","ocean"]:
			var race:=Race.new([{"slot":0,"bot":true}],seed_value,3,"hard",biome)
			var track:RefCounted=race.track
			var start:=0.;var end:=0.;var exposed:=0
			for i in range(track.nodes.size()):
				var n:Dictionary=track.nodes[i]
				if n.feature!="hairpin": continue
				if start==0.: start=i*track.step-230.
				end=i*track.step+40.
				check(n.width>=22.,"Hard hairpin has at least 44 m usable road")
				var q:float=(n.u-track.components[0].start)/(track.components[0].end-track.components[0].start)
				if q<.12 or q>.88: check(n.rails,"Seed-dependent hairpin entry/exit have recovery rails")
				if not n.rails: exposed+=1
			check(exposed*track.step>500.,"Hairpin retains a substantial exposed technical section")
			# Widening the deck must not make the returning lanes intersect.
			for i in range(0,track.nodes.size(),8):
				if track.nodes[i].feature!="hairpin": continue
				for j in range(0,track.nodes.size(),8):
					if minf(absf(j-i)*track.step,track.length-absf(j-i)*track.step)<200.: continue
					var a:=Race.Track.cross_section_sphere(track.nodes[i]);var b:=Race.Track.cross_section_sphere(track.nodes[j])
					check(a.center.distance_to(b.center)>=a.radius+b.radius+5.,"Wider switchback decks remain separated")
			for offset in [-8.,0.,8.]:
				race.countdown=0.;race.clock=10.
				var p:Dictionary=race.racers[0];p.distance=start;p.x=offset;p.speed=250.;p.heading=0.;p.slip=0.;p.airborne=false;p.crashed=false
				var braking:=0.
				for tick in range(120*30):
					var input:Dictionary=race.bot(p);input.fire=false;input.boost=false
					braking+=float(input.get("brake",0.))/120.
					race.step(1./120.,[input])
					if p.crashed or p.airborne or p.distance>=end: break
				check(p.distance>=end and not p.crashed and not p.airborne,"Deliberate braking survives from varied entry lines: %d %s %s"%[seed_value,biome,offset])
				check(braking>.3,"Hard hairpin continues to require deliberate braking")
				print("HARD_FAIRNESS seed=",seed_value," biome=",biome," entry=",offset," completed=",p.distance>=end," braking=",braking)
	print("HARD_FAIRNESS_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
