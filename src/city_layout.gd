extends RefCounted
## Deterministic city lots with a conservative 3D swept-road exclusion volume.
const CELL:=120.0
const FLOOR:=-180.0
var corridor:Dictionary={}
var buildings:Array[Dictionary]=[]
var signs:Array[Dictionary]=[]
var routes:Array[Dictionary]=[]
var billboards:Array[Dictionary]=[]

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
			var kind:=rng.randi_range(0,7)
			var width:=rng.randf_range(28,100)
			var depth:=rng.randf_range(30,94)
			var height:=rng.randf_range(180,620)
			if kind==6: # wide commercial blocks occupy more than one city lot
				width=rng.randf_range(125,195)
				depth=rng.randf_range(65,100)
				height=rng.randf_range(110,270)
			elif kind==3: # slender landmark towers
				width=rng.randf_range(24,42)
				depth=width*rng.randf_range(.8,1.2)
			if rng.randf()<.12: height=rng.randf_range(650,860)
			var center:=Vector3(x*CELL+rng.randf_range(-7,7),FLOOR,z*CELL+rng.randf_range(-7,7))
			var bounds:=AABB(center-Vector3(width*.5,0,depth*.5),Vector3(width,height+180,depth))
			if not clear(bounds) or occupied(bounds.grow(5)): continue
			var sign_hit:=false
			for sign_value in signs:
				if bounds.intersects(sign_value.bounds): sign_hit=true;break
			if sign_hit: continue
			buildings.append({"center":center,"width":width,"depth":depth,"height":height,
				"kind":kind,"roof":rng.randi_range(0,5),"roof_height":rng.randf_range(22,55),"antenna":rng.randf_range(35,80),"color":Color(rng.randf(),rng.randf(),rng.randf()),"bounds":bounds})
	place_billboards(track)
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

func place_billboards(track:RefCounted)->void:
	# Slabs leave a margin inside the audited lot, so the attached screens and frames
	# stay inside the same collision-free building envelope, including on loops.
	for index in range(buildings.size()):
		var building:Dictionary=buildings[index]
		if building.kind!=0 or building.height<230: continue
		var nearest:=Vector3.ZERO
		var distance:=INF
		for n in track.nodes:
			var delta:Vector3=n.p-building.center
			var horizontal:=Vector2(delta.x,delta.z).length_squared()
			if horizontal<distance: nearest=n.p;distance=horizontal
		if distance>550*550: continue
		var direction:Vector3=nearest-building.center
		var normal:=Vector3(signf(direction.x),0,0) if absf(direction.x)>absf(direction.z) else Vector3(0,0,signf(direction.z))
		var on_x:=absf(normal.x)>.5
		var width:float=(building.depth*.82 if on_x else building.width*.78)*.88
		var height:=width*2.5
		var center_y:=clampf(nearest.y+height*.8,building.center.y+building.height*.15+height*.5,building.center.y+building.height-height*.5-8)
		var position:Vector3=building.center+normal*((building.width*.39 if on_x else building.depth*.41)+.7)
		position.y=center_y
		var frame:=Basis(Vector3.UP.cross(normal),Vector3.UP,normal)
		var transform_value:=Transform3D(frame,position)
		var bounds:AABB=transform_value*AABB(Vector3(-width*.5-.6,-height*.5-.6,-.25),Vector3(width+1.2,height+1.2,.7))
		if not building.bounds.encloses(bounds) or not clear(bounds): continue
		billboards.append({"transform":transform_value,"size":Vector2(width,height),"variant":index%4,"building":index,"bounds":bounds})
