extends RefCounted
## Sparse, optional flight detours. Uses a separate seed so weapon rolls stay stable.
const Track=preload("res://src/track.gd")
const RADIUS:=6.

static func generate(track:RefCounted,batteries:Array[Dictionary])->void:
	var random:=RandomNumberGenerator.new();random.seed=track.seed_value+774211
	var distance:=800.+random.randf_range(0.,200.)
	var count:=0
	while distance<track.length-500. and count<4:
		var clear:=true
		for offset in [-180.,-90.,0.,90.,180.]:
			var probe:Dictionary=track.sample(distance+offset)
			if probe.loop or probe.tunnel or probe.air_gap or probe.shape_angle>.01 or probe.split_gap>.01 or probe.feature in ["jump","flight"] or absf(probe.curve)>.005 or probe.frame.y.dot(Vector3.UP)<.85:
				clear=false;break
		if not clear or batteries.any(func(b):return absf(b.distance-distance)<120.):
			distance+=70.;continue
		var n:Dictionary=track.sample(distance)
		var difficulty:int=["easy","normal","hard"].find(track.difficulty)
		var height:float=[15.,22.,30.][difficulty]+random.randf_range(0.,5.)
		var side:=(-1. if (count+track.seed_value)%2==0 else 1.)
		var lateral:float=side*n.width*[.60,.85,1.08][difficulty]
		batteries.append({"distance":distance,"x":lateral,"air":true,"claimed":{},"cooldown":0.,"reveal":1.,
			"pose":Transform3D(n.frame,Track.point(n,lateral,height))})
		count+=1;distance+=1300.+random.randf_range(0.,300.)
	# Compact, technical tracks may have no long open straight. Their existing
	# jumps offer optional higher, off-axis detours instead of forcing a new jump.
	for jump in track.jumps:
		if count>=2: break
		var at:float=(jump.takeoff+jump.landing)*.5
		if batteries.any(func(b):return absf(b.distance-at)<(500. if b.get("air",false) else 120.)): continue
		var n:Dictionary=track.sample(at)
		if n.frame.y.dot(Vector3.UP)<.75: continue
		var side:=(-1. if (count+track.seed_value)%2==0 else 1.)
		var lateral:float=side*n.width*(1.08 if track.difficulty=="hard" else .85)
		var height:=32. if track.difficulty=="hard" else 24.
		batteries.append({"distance":at,"x":lateral,"air":true,"claimed":{},"cooldown":0.,"reveal":1.,
			"pose":Transform3D(n.frame,Track.point(n,lateral,height))})
		count+=1

static func route_clear(track:RefCounted,battery:Dictionary)->bool:
	var position:Vector3=battery.pose.origin
	# Reject an overhead/crossing road deck near the pickup itself.
	for i in range(track.nodes.size()):
		if absf(wrapf(i*track.step-battery.distance,-track.length*.5,track.length*.5))<220.: continue
		var n:Dictionary=track.nodes[i]
		if position.distance_to(n.p)<n.width+RADIUS: return false
	if track.obstacles==null: return true
	var approach:Vector3=Track.point(track.sample(battery.distance-160.),0.,7.)
	var exit_point:Vector3=Track.point(track.sample(battery.distance+180.),0.,7.)
	return track.obstacles.trace(approach,position,RADIUS).is_empty() and track.obstacles.trace(position,exit_point,RADIUS).is_empty()

static func validate(track:RefCounted,batteries:Array[Dictionary])->void:
	# Scenery collision is available after world construction. Unsafe detours are
	# omitted before making the shared instanced battery meshes.
	for battery in batteries.duplicate():
		if battery.get("air",false) and not route_clear(track,battery): batteries.erase(battery)

static func crossed(p:Dictionary,battery:Dictionary)->bool:
	if not p.airborne or not p.get("weapon_was_airborne",false): return false
	if not p.has("weapon_position_before"): return false
	var from:Vector3=p.weapon_position_before
	var to:Vector3=p.air_position
	if from.distance_squared_to(to)>120.*120.: return false
	var closest:=Geometry3D.get_closest_point_to_segment(battery.pose.origin,from,to)
	return closest.distance_squared_to(battery.pose.origin)<=RADIUS*RADIUS
