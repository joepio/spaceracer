extends RefCounted
## Deterministic city lots with a conservative 3D swept-road exclusion volume.
const CELL:=120.0
const FLOOR:=-180.0
var corridor:Dictionary={}
var buildings:Array[Dictionary]=[]
var signs:Array[Dictionary]=[]
var routes:Array[Dictionary]=[]

func _init(track:RefCounted)->void:
	for i in range(track.nodes.size()):
		var a:Dictionary=track.nodes[i]
		var b:Dictionary=track.nodes[(i+1)%track.nodes.size()]
		var bounds:=AABB(a.p,Vector3.ZERO).expand(b.p).grow(maxf(a.width,b.width)+18)
		for cell in cells(bounds):
			if not corridor.has(cell): corridor[cell]=[]
			corridor[cell].append(bounds)
	for i in range(25,track.nodes.size(),47):
		var n:Dictionary=track.nodes[i]
		if n.loop or n.tunnel: continue
		var side:=1.0 if i%2==0 else -1.0
		var position:Vector3=n.p+n.frame.x*side*(n.width+84)+n.frame.y*27
		var frame:=Basis(-n.frame.x,n.frame.y,-n.frame.z)
		var bounds: AABB=Transform3D(frame,position)*AABB(Vector3(-24,-11,-2),Vector3(48,22,4))
		bounds=bounds.grow(2.5)
		if not clear(bounds): continue
		signs.append({"transform":Transform3D(frame,position),"bounds":bounds})
	var rng:=RandomNumberGenerator.new()
	rng.seed=track.seed_value+170
	for x in range(-18,19):
		for z in range(-18,19):
			if rng.randf()<.12: continue
			var width:=rng.randf_range(42,84)
			var depth:=rng.randf_range(40,84)
			var height:=rng.randf_range(160,620)
			if rng.randf()<.12: height=rng.randf_range(650,860)
			var center:=Vector3(x*CELL+rng.randf_range(-7,7),FLOOR,z*CELL+rng.randf_range(-7,7))
			var bounds:=AABB(center-Vector3(width*.5,0,depth*.5),Vector3(width,height+38,depth))
			if not clear(bounds): continue
			var sign_hit:=false
			for sign_value in signs:
				if bounds.intersects(sign_value.bounds): sign_hit=true;break
			if sign_hit: continue
			buildings.append({"center":center,"width":width,"depth":depth,"height":height,
				"kind":rng.randi_range(0,5),"color":Color(rng.randf(),rng.randf(),rng.randf()),"bounds":bounds})
	# Air lanes run along the gaps between city lots; reject spans near the ribbon.
	for row in range(-14,15,2):
		for block in range(-3,4):
			var start:=Vector3(block*480,80+posmod(row,3)*85,row*CELL+CELL*.5)
			var bounds:=AABB(start-Vector3(14,5,5),Vector3(508,10,10))
			if not clear(bounds) or occupied(bounds): continue
			var sign_hit:=false
			for sign_value in signs:
				if bounds.intersects(sign_value.bounds): sign_hit=true;break
			if not sign_hit: routes.append({"start":start,"length":480.0,"direction":1.0 if row%4==0 else -1.0,"bounds":bounds})

static func cells(bounds:AABB)->Array[Vector2i]:
	var result:Array[Vector2i]=[]
	for x in range(floori(bounds.position.x/128),floori(bounds.end.x/128)+1):
		for z in range(floori(bounds.position.z/128),floori(bounds.end.z/128)+1): result.append(Vector2i(x,z))
	return result

func clear(bounds:AABB)->bool:
	for cell in cells(bounds):
		for road:AABB in corridor.get(cell,[]):
			if road.intersects(bounds): return false
	return true

func occupied(bounds:AABB)->bool:
	for building in buildings:
		if bounds.intersects(building.bounds): return true
	return false
