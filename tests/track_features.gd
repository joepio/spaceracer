extends SceneTree
const Track=preload("res://src/track.gd")
const Race=preload("res://src/race.gd")
const Flight=preload("res://src/flight.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<15: push_error(message)
func _initialize()->void: call_deferred("run")
func feature_distance(track:RefCounted,kind:String)->float:
	var matches:Array=[]
	for i in range(track.nodes.size()):
		if track.nodes[i].feature==kind: matches.append(i)
		elif not matches.is_empty(): break
	return matches[matches.size()/2]*track.step
func run()->void:
	var covered:Array=[]
	for seed_value in [1,2,3,9,17,31,32,33,34,35,36,42,145]:
		var track:=Track.new(seed_value)
		var repeat:=Track.new(seed_value)
		check(track.features==repeat.features,"Feature placement and dimensions reproduce from short seed")
		for kind in ["open","halfpipe","tube","split"]:
			if not track.nodes.any(func(n):return n.feature==kind): continue
			if kind not in covered: covered.append(kind)
			var distance:=feature_distance(track,kind)
			var n:Dictionary=track.sample(distance)
			check(n.feature==kind,"Feature placement matches the selected recipe")
			for fraction in [-.95,-.5,0.,.5,.95]:
				var lateral:float=n.width*fraction
				var point:=Track.point(n,lateral,1.3)
				check(absf(Track.lateral_at(n,point)-lateral)<.002,"Curved-surface projection inverts geometry")
				var frame:=Track.surface_frame(n,lateral)
				check(frame.determinant()>.999 and frame.y.dot((point-Track.point(n,lateral)).normalized())>.999,"Hover and vehicle normal match rideable surface")
			if kind=="tube":
				check(Track.closed_tube(n),"Tube has a fully closed rideable section")
				check(Track.point(n,-n.width).distance_to(Track.point(n,n.width))<.002,"Tube joins seamlessly at the ceiling")
				check(Track.surface_frame(n,n.width).y.dot(n.frame.y)<-.9,"Ceiling driving is genuinely inverted, including longitudinal banking")
			if kind=="split":
				check(not Track.supported(n,0.,1.),"Split has a real unsupported centre gap")
				check(Track.supported(n,(n.width+n.split_gap)*.5,5.8),"Each fork has room for the full ship")
		# Across longitudinal transitions, the bottom driving path stays continuous.
		for i in range(track.nodes.size()):
			var a:Dictionary=track.nodes[i]
			var b:Dictionary=track.nodes[(i+1)%track.nodes.size()]
			check(Track.point(a,0).distance_to(Track.point(b,0))<track.step*1.01,"Feature transitions preserve the centreline")
	check(covered.size()==4,"Track families collectively cover every curved/split/open component")
	var race:=Race.new([{"slot":0},{"slot":1}],31)
	race.countdown=0.
	var p:Dictionary=race.racers[0]
	var open_distance:=feature_distance(race.track,"open")
	p.distance=open_distance
	var n:Dictionary=race.track.sample(open_distance)
	p.x=n.width+1.
	p.speed=200.
	p.slip=60.
	race.racers[1].distance=0
	race.step(.008,[{"throttle":1.0},{}])
	check(p.airborne and p.recovery==0,"Driving beyond a rail-free edge enters controllable flight")
	var tube_distance:=feature_distance(race.track,"tube")
	n=race.track.sample(tube_distance)
	p.airborne=false
	p.distance=tube_distance
	p.x=n.width+2.
	var ceiling_before:=Flight.ground_pose(p,n,0.)
	Race.constrain_surface(p,n)
	var ceiling_after:=Flight.ground_pose(p,n,0.)
	check(p.x<0 and ceiling_before.origin.distance_to(ceiling_after.origin)<.001 and ceiling_before.basis.y.dot(ceiling_after.basis.y)>.999,"Crossing tube seam preserves position and orientation")
	var other:Dictionary=race.racers[1]
	p.x=n.width-1.;p.heading=0.;p.slip=0.
	other.distance=tube_distance;other.x=-n.width+1.;other.heading=0.;other.slip=0.
	check(race.contact(p,other).length()>1.,"Cars collide across the wrapped tube seam")
	race.resolve_contacts()
	check(race.contact(p,other).length()<.02,"Ceiling seam collision separates both hulls")
	# Both branch choices traverse a complete fork and merge with valid lap progress.
	for side in [-1.,1.]:
		var fork:Dictionary=race.track.features.filter(func(f):return f.kind=="split")[0]
		var first:=0
		var last:=0
		for i in range(race.track.nodes.size()):
			if race.track.nodes[i].u<fork.start: first=i
			if race.track.nodes[i].u<fork.end: last=i
		p.x=side*12.
		p.route=0.
		p.slip=0.
		p.heading=0.
		for i in range(first,last+2):
			p.distance=i*race.track.step
			n=race.track.sample(p.distance)
			Race.constrain_surface(p,n)
			if n.split_gap>3: check(Track.supported(n,p.x,4.7),"Fork constraint stays on the chosen solid deck")
		check(p.route==0. and p.x*side>0.,"Both forks merge back without forcing a lane change")
	# A legal descent onto the curved tube wall can reattach.
	n=race.track.sample(tube_distance)
	var lateral:float=n.width*.48
	var frame:=Track.surface_frame(n,lateral)
	p.airborne=true;p.distance=tube_distance;p.air_time=.5;p.air_travel=0.
	p.air_position=Track.point(n,lateral,1.7)
	p.air_velocity=frame.z*220.-frame.y*45.
	p.air_frame=frame;p.air_rates=Vector3.ZERO;p.trim=0.;p.recovery=0.;p.crashed=false
	for i in range(10):
		if not p.airborne: break
		Flight.step(p,race.track,.008,0.,0.,.5,0.)
	check(not p.airborne and not p.crashed and p.recovery==0.,"Flight can land on a tube wall using its local surface normal")
	print("TRACK_FEATURE_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
