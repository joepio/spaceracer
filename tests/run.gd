extends SceneTree
const Race = preload("res://src/race.gd")
const Track = preload("res://src/track.gd")
const Bridge = preload("res://src/bridge.gd")
# Wide test surface isolates handling from rail bounces and random track geometry.
class TestRoad extends RefCounted:
	var length:=100000.0
	var bend:=0.0
	var crest:=0.0
	func sample(_distance:float)->Dictionary:
		return {"p":Vector3(0,0,_distance),"frame":Basis.IDENTITY,"width":500.0,"curve":bend,"crest":crest,"slope":0.0,"zone":""}
	func project(position:Vector3,_reference:float,_reach:float)->Dictionary:
		return {"distance":position.z,"lateral":-position.x,"node":sample(position.z)}

func handling_race()->RefCounted:
	var result:=Race.new(roster(),31)
	result.track=TestRoad.new()
	result.countdown=0
	result.racers[0].speed=265.0
	return result

var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures < 15: push_error(message)

func roster(count: int = 1) -> Array:
	var out: Array = []
	for i in range(count): out.append({"slot":i,"name":"Pilot %d"%i,"bot":true})
	return out

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for seed_value in range(1,41):
		var track := Track.new(seed_value)
		var repeat := Track.new(seed_value)
		check(is_equal_approx(track.length, repeat.length),"Track seeds must reproduce")
		var seam_a: Dictionary = track.sample(track.length - .01)
		var seam_b: Dictionary = track.sample(.01)
		check(seam_a.p.distance_to(seam_b.p)<.03,"Closed track position seam")
		check(absf(angle_difference(seam_a.heading,seam_b.heading))<.001,"Closed track tangent seam")
		var inverted:=false
		var min_height:=INF
		var max_height:=-INF
		for index in range(track.nodes.size()):
			var node:Dictionary=track.nodes[index]
			check(node.width>=23 and node.width<=104. and absf(node.bank)<=.621,"Driveable arc width/bank, including pipes and forks")
			var basis := Track.basis_at(node)
			check(basis.determinant()>.99,"Track basis must be right handed")
			check((Track.point(node,1)-node.p).dot(-basis.x)>.9,"Positive lateral input points screen-right")
			check((Track.point(node,0,1)-node.p).dot(basis.y)>.99,"Hover height follows road, including inverted sections")
			var next:Basis=track.nodes[(index+1)%track.nodes.size()].frame
			check(basis.y.dot(next.y)>.85,"No camera/road roll flips")
			inverted=inverted or basis.y.y<-.65
			min_height=minf(min_height,node.p.y)
			max_height=maxf(max_height,node.p.y)
		check(inverted,"Every seed contains a rideable inverted loop")
		check(max_height-min_height>350,"Meaningful vertical relief")
		var clear:=true
		for i in range(0,track.nodes.size(),6):
			for j in range(i+6,track.nodes.size(),6):
				var arc:=minf((j-i)*track.step,track.length-(j-i)*track.step)
				if arc<200: continue
				var a:Dictionary=track.nodes[i]
				var b:Dictionary=track.nodes[j]
				var a_bounds:=Track.cross_section_sphere(a)
				var b_bounds:=Track.cross_section_sphere(b)
				if a_bounds.center.distance_to(b_bounds.center)<a_bounds.radius+b_bounds.radius+5: clear=false
		check(clear,"Non-neighboring road sections clear each other, seed %d"%seed_value)
	print("PASS deterministic tracks and continuous banked geometry")
	# Ground handling contracts use a protected course without mandatory gaps.
	var race := Race.new(roster(),42,3,"easy")
	var p: Dictionary = race.racers[0]
	race.step(1.0,[{"throttle":1.0}])
	check(p.distance==0 and p.speed==0,"Countdown freezes launch")
	race.countdown=0
	for i in range(600): race.step(1.0/120,[race.bot(p)])
	check(p.speed>220 and p.speed<280,"Top speed and acceleration")
	var speed: float=p.speed
	for i in range(60): race.step(1.0/120,[{"brake":true}])
	check(p.speed<speed-75,"Brake rapidly reduces speed")
	p.energy=100.0
	p.boost_held=false
	race.step(1.0/120,[{"boost":true}])
	check(p.boost==0 and p.energy==100,"Lap one boost is locked")
	p.distance=race.track.length*1.15
	p.lap=2
	p.boost_held=false
	p.speed=260.0
	p.x=0.0
	race.step(1.0/120,[{"boost":true,"throttle":1.0}])
	check(p.boost>1 and is_equal_approx(p.energy,78),"Boost spends exactly 22 energy")
	for i in range(70): race.step(1.0/120,[{"boost":true,"throttle":1.0}])
	check(p.boost<1,"Held boost does not retrigger")
	check(p.speed>300,"Boost exceeds normal maximum")
	p.distance=race.track.length*.02
	p.x=-20.0
	p.energy=40.0
	p.slip=0.0
	p.heading=0.0
	p.speed=0.0
	p.boost=0.0
	race.step(1.0/120,[{}])
	check(p.energy>40,"Repair lane replenishes energy")
	p.x=100.0
	p.slip=100.0
	p.energy=1.0
	race.step(1.0/120,[{"steer":1.0,"throttle":1.0}])
	check(p.recovery>0,"Energy depletion enters recovery")
	for i in range(241): race.step(1.0/120,[{}])
	check(p.recovery==0 and p.energy>=65,"Recovery cannot strand a racer")
	var grip := Race.new(roster(),52)
	var drift := Race.new(roster(),52)
	for test_race in [grip,drift]:
		test_race.countdown=0
		test_race.racers[0].speed=200.0
	for i in range(20):
		grip.step(1.0/120,[{"steer":.6,"throttle":1.0}])
		drift.step(1.0/120,[{"steer":.6,"throttle":1.0,"brake":1.0}])
	check(drift.racers[0].heading>grip.racers[0].heading,"LT slide increases yaw authority")
	var finish := Race.new(roster(2),2,1)
	finish.countdown=0
	finish.racers[0].distance=finish.track.length-1
	finish.racers[0].speed=200.0
	finish.step(.01,[{"throttle":1.0},{}])
	check(finish.racers[0].finished and not finish.over,"First finisher gives rivals a grace period")
	finish.clock=finish.finish_deadline
	finish.step(.01,[{},{}])
	check(finish.over and finish.standings()[0].slot==0,"Finish timeout and standings")
	print("PASS acceleration, braking, boost, grip, recovery, laps, results")
	var pack:=Race.new(roster(6),31)
	for i in range(6):
		for j in range(i+1,6):
			check(pack.contact(pack.racers[i],pack.racers[j])==Vector2.ZERO,"Grid clears full ship meshes")
	var pair:=Race.new(roster(2),31)
	var a:Dictionary=pair.racers[0]
	var b:Dictionary=pair.racers[1]
	for headings in [Vector2.ZERO,Vector2(.7,-.6),Vector2(-.8,-.5)]:
		a.merge({"x":0.0,"distance":100.0,"heading":headings.x,"speed":300.0,"slip":30.0},true)
		b.merge({"x":6.0,"distance":100.0,"heading":headings.y,"speed":240.0,"slip":-30.0},true)
		pair.resolve_contacts()
		check(pair.contact(a,b).length()<.02,"Side impacts separate rotated wings")
	a.merge({"x":0.0,"distance":100.0,"heading":0.0,"speed":390.0,"slip":0.0},true)
	b.merge({"x":0.0,"distance":105.0,"heading":0.0,"speed":100.0,"slip":0.0},true)
	pair.resolve_contacts()
	check(pair.contact(a,b).length()<.02 and a.distance<b.distance,"Rear impact cannot pass through hull")
	check(a.speed<390 and b.speed>100,"Rear impact transfers closing momentum")
	a.distance=pair.track.length-2
	b.distance=2
	pair.resolve_contacts()
	check(pair.contact(a,b).length()<.02,"Contact wraps across lap seam")
	for i in range(6):
		pack.racers[i].x=12.0+(i%3)*2.0
		pack.racers[i].distance=100.0+floorf(i/3.0)*7
	for iteration in range(12): pack.resolve_contacts()
	for i in range(6):
		var r:Dictionary=pack.racers[i]
		check(absf(r.x)<=pack.lateral_limit(r,pack.track.sample(r.distance).width)+.01,"Pack stays inside rail with full wing clearance")
		for j in range(i+1,6):
			check(pack.contact(r,pack.racers[j]).length()<.03,"Congested pack resolves without interpenetration")
	var responsive:=Race.new(roster(),31)
	responsive.countdown=0
	responsive.racers[0].speed=200.0
	for tick in range(12): responsive.step(1.0/120,[{"right":true,"throttle":1.0}])
	check(responsive.racers[0].slip>30,"Strafe reaches strong lateral speed within 100 ms")
	print("PASS full-hull contacts, rear impacts, rotated wings, grid, rail crowding and strafe response")
	var dry:=handling_race()
	var sliding:=handling_race()
	var feather:=handling_race()
	for tick in range(24):
		dry.step(1.0/120,[{"steer":.65,"throttle":1.0}])
		sliding.step(1.0/120,[{"steer":.65,"throttle":1.0,"brake":1.0}])
		feather.step(1.0/120,[{"steer":.65,"throttle":1.0,"brake":.35}])
	var dry_p:Dictionary=dry.racers[0]
	var slide_p:Dictionary=sliding.racers[0]
	check(slide_p.heading>dry_p.heading+.06,"Brake rotates hull more sharply")
	check(absf(sin(slide_p.heading)*slide_p.speed-slide_p.slip)>absf(sin(dry_p.heading)*dry_p.speed-dry_p.slip)+10,"Brake retains momentum separately from nose direction")
	check(feather.racers[0].speed>slide_p.speed and feather.racers[0].slide<slide_p.slide,"LT analog pressure scales braking and slide")
	for tick in range(90): sliding.step(1.0/120,[{"steer":-.15,"throttle":1.0,"trim":1.0}])
	check(slide_p.slide==0 and absf(sin(slide_p.heading)*slide_p.speed-slide_p.slip)<8,"Release brake and countersteer catches slide")
	var tapped:=handling_race()
	for tick in range(8): tapped.step(1.0/120,[{"throttle":1.0,"steer":.65,"brake":1.0}])
	check(tapped.racers[0].slide>.85,"A 67 ms brake tap releases magnetic grip")
	for tick in range(42): tapped.step(1.0/120,[{"throttle":1.0,"steer":.35}])
	var tap:Dictionary=tapped.racers[0]
	check(tap.slide>.65 and tap.braking==0,"Slide lingers after a short brake release")
	check(absf(sin(tap.heading)*tap.speed-tap.slip)>20,"Low grip visibly separates heading from lateral momentum")
	for tick in range(240): tapped.step(1.0/120,[{"throttle":1.0}])
	check(tap.slide==0,"Grip eventually returns without requiring more input")
	var stable:=handling_race()
	var neutral:=handling_race()
	var risky:=handling_race()
	for tick in range(600):
		stable.step(1.0/120,[{"throttle":1.0,"trim":1.0}])
		neutral.step(1.0/120,[{"throttle":1.0}])
		risky.step(1.0/120,[{"throttle":1.0,"trim":-.65}])
	check(stable.racers[0].speed<neutral.racers[0].speed-30,"Right stick forward trades speed for grip")
	check(risky.racers[0].speed>neutral.racers[0].speed+25,"Right stick back increases speed")
	for test_race in [stable,risky]:
		test_race.racers[0].speed=300.0
		test_race.track.crest=-.006
	for tick in range(150):
		stable.step(1.0/120,[{"throttle":1.0,"trim":1.0}])
		risky.step(1.0/120,[{"throttle":1.0,"trim":-1.0}])
	check(risky.racers[0].airborne and risky.racers[0].lift>1,"Low downforce lifts craft off a fast crest")
	check(stable.racers[0].lift==0,"Forward right stick keeps craft planted")
	risky.track.crest=0.0
	var airborne:Dictionary=risky.racers[0]
	airborne.air_position=Vector3(0,1.8,100)
	airborne.air_velocity=Vector3(0,-20,220)
	airborne.air_frame=Basis.IDENTITY
	airborne.air_time=.5
	airborne.trim=0.0
	Race.Flight.step(airborne,risky.track,.05,0,0,0,0)
	check(not airborne.airborne and airborne.recovery==0,"Aligned downward crossing lands on track")
	airborne.airborne=true
	airborne.air_time=10.1
	Race.Flight.step(airborne,risky.track,1.0/120,0,0,0,0)
	check(airborne.recovery>0 and airborne.crashed,"Runaway flight crashes then respawns")
	var analog_strafe:=handling_race()
	for tick in range(24): analog_strafe.step(1.0/120,[{"strafe":.6,"throttle":1.0}])
	check(analog_strafe.racers[0].slip>20 and analog_strafe.racers[0].heading==0,"Right stick strafes without steering nose")
	var corner_track:=Track.new(31)
	var tight:=0
	var sweeping:=0
	for node in corner_track.nodes:
		if not node.loop and absf(node.curve)>.008: tight+=1
		if absf(node.curve)<.002: sweeping+=1
	check(tight>=8 and sweeping>corner_track.nodes.size()*.35,"Circuit mixes demanding corners and high speed sweepers")
	print("PASS analog brake slide, catch, downforce/speed, crest flight, landing, analog strafe and sharp corners")
	var completed := 0
	var worst_time := 0.0
	for seed_value in range(1,13):
		var soak := Race.new(roster(4),seed_value,3)
		for tick in range(120*220):
			var inputs: Array=[]
			for racer in soak.racers: inputs.append(soak.bot(racer))
			soak.step(1.0/120,inputs)
			if soak.over: break
		for racer in soak.racers:
			check(is_finite(racer.speed) and is_finite(racer.x) and is_finite(racer.distance),"Soak remains finite")
			check(racer.energy>=0 and racer.energy<=100,"Energy remains bounded")
			if racer.finished: completed+=1
		check(soak.racers.any(func(r:Dictionary)->bool:return r.finished),"Bots finish seed %d"%seed_value)
		worst_time=maxf(worst_time,soak.clock)
	print("SOAK %d / 48 finishers; longest race %.2fs"%[completed,worst_time])
	var bridge := Bridge.new()
	root.add_child(bridge)
	bridge._handle({"type":"controller_frame","controllers":[
		{"controller":"ordinal:7","axes":[-32767,0,0,0,0,32767],"buttons":16},
		{"controller":"ordinal:2","axes":[32767,0,0,0,0,0],"buttons":2}]})
	check(bridge.controls("ordinal:7").steer==-1 and bridge.controls("ordinal:7").throttle==1,"Host routes opaque controller token")
	check(bridge.controls("ordinal:2").boost and bridge.controls("missing").steer==0,"Sparse seats never steal input")
	bridge._handle({"type":"controller_frame","controllers":[{"controller":"sticks","axes":[0,0,16384,-32767,16384,0],"buttons":0}]})
	var stick:Dictionary=bridge.controls("sticks")
	check(stick.trim==1 and stick.strafe>.4 and stick.strafe<.5,"Host maps right stick forward and analog strafe")
	check(stick.brake>.45 and stick.brake<.5,"Host preserves analog LT pressure")
	bridge.frame_at-=251
	check(bridge.controls("ordinal:7").throttle==0,"Stale frames become neutral")
	bridge.session="one"
	bridge.phase="running"
	bridge._handle({"type":"pause","session":"other"})
	check(bridge.phase=="running","Ignore commands for stale sessions")
	bridge._handle({"type":"pause","session":"one"})
	check(bridge.phase=="paused","Pause explicit session")
	bridge._handle({"type":"resume","session":"one"})
	check(bridge.phase=="running","Resume explicit session")
	bridge.free()
	print("ION_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
