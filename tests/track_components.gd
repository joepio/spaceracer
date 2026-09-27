extends SceneTree
const Race=preload("res://src/race.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func arc(track:RefCounted,u:float)->float:
	for i in range(track.nodes.size()):
		if track.nodes[i].u>=u: return i*track.step
	return 0.
func drive(seed_value:int,kind:String,reckless:bool=false)->Dictionary:
	var race:=Race.new([{"slot":0,"bot":true}],seed_value,3,"hard")
	race.countdown=0.;race.clock=10.
	var p:Dictionary=race.racers[0];p.x=0.;p.speed=250.
	var start:=0.;var end:=0.
	if kind=="turbo":
		start=race.track.jumps[0].takeoff-230.;end=race.track.jumps[0].landing+100.
	else:
		var c:Dictionary=race.track.components[0]
		start=arc(race.track,c.start)-230.;end=arc(race.track,c.end)+40.
	p.distance=start
	var air:=false;var landed:=false;var braking:=0.;var trim:=0.;var peak:=0.;var escaped:=false
	for tick in range(120*28):
		var input:Dictionary=race.bot(p);input.fire=false;input.boost=false
		if reckless:
			input.brake=0.
			if p.airborne: input={"throttle":1.,"trim":0.,"steer":0.,"strafe":0.}
		braking+=float(input.get("brake",0.))/120.
		trim=maxf(trim,float(input.get("trim",0.)))
		var before:bool=p.airborne
		race.step(1./120.,[input]);peak=maxf(peak,p.speed)
		if p.airborne: air=true
		if before and not p.airborne and not p.crashed: landed=true
		if kind=="hairpin" and p.airborne: escaped=true;break
		if p.crashed or p.distance>=end: break
	var result:={"seed":seed_value,"kind":kind,"reckless":reckless,"completed":p.distance>=end and not p.crashed and not p.airborne,"crashed":p.crashed,"escaped":escaped,"braking":braking,"air":air,"landed":landed,"nose_down":trim,"peak":peak,"progress":p.distance-start,"target":end-start}
	print("COMPONENT_DRIVE ",JSON.stringify(result))
	return result
func run()->void:
	for seed_value in range(1,73):
		if Race.Track.Profiles.index(seed_value) not in [0,2]: continue
		for biome in ["city","forest"]:
			var track:=Race.Track.new(seed_value,"hard",biome)
			for i in range(0,track.nodes.size(),8):
				for j in range(i+8,track.nodes.size(),8):
					if minf((j-i)*track.step,track.length-(j-i)*track.step)<200.: continue
					var a:=Race.Track.cross_section_sphere(track.nodes[i])
					var b:=Race.Track.cross_section_sphere(track.nodes[j])
					check(a.center.distance_to(b.center)>=a.radius+b.radius+5.,"Component clearance seed %d %s"%[seed_value,biome])
	var spiral:=drive(31,"spiral")
	check(spiral.completed,"Spiral is driveable")
	var hairpin:=drive(33,"hairpin")
	check(hairpin.completed and hairpin.braking>.3,"Hairpin is survivable with deliberate braking")
	var reckless:=drive(33,"hairpin",true)
	check(not reckless.completed,"Full throttle cannot stay on the exposed hairpin")
	for seed_value in [31,34,35]:
		var jump:=drive(seed_value,"turbo")
		check(jump.completed and jump.air and jump.landed and jump.nose_down>.1,"Turbo ramp needs controlled flight and can be landed")
	var neutral:=drive(35,"turbo",true)
	check(not neutral.completed,"Neutral flight cannot simply coast onto the turbo landing")
	for seed_value in [31,37]:
		var race:=Race.new([{"slot":0,"bot":false}],seed_value,3,"hard")
		var h:Dictionary=race.track.dead_ends[0]
		var n:Dictionary=race.track.sample(h.distance+10.)
		check(not Race.Track.supported(n,h.side*(n.width+n.split_gap)*.5),"Dead branch has no hidden collision road")
		check(Race.Track.supported(n,-h.side*(n.width+n.split_gap)*.5),"Alternate branch stays open")
		var p:Dictionary=race.racers[0];race.countdown=0.;p.speed=200.;p.distance=h.distance-20.
		n=race.track.sample(p.distance);p.x=h.side*(n.width+n.split_gap)*.5;p.route=h.side
		for tick in range(30):
			race.step(1./120.,[{"throttle":1.}])
			if p.crashed or p.airborne: break
		check(race.track.sample(race.track.safe_respawn(h.distance)).split_gap==0.,"Recovery returns before the branch choice")
		check(p.crashed if h.wall else p.airborne,"Wrong route crashes into the barrier or flies off the broken deck")
	print("COMPONENT_TESTS failures=",failures)
	quit(1 if failures else 0)
