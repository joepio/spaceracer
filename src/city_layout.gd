extends RefCounted
## Deterministic city lots with a conservative 3D swept-road exclusion volume.
const CELL:=120.0
const FLOOR:=-180.0
var corridor:Dictionary={}
var buildings:Array[Dictionary]=[]
var routes:Array[Dictionary]=[]
var billboards:Array[Dictionary]=[]
var vista_from:=Vector3.ZERO
var vista_targets:Array[Vector3]=[]

func _init(track:RefCounted)->void:
	# Keep a view of the first loop from the approach, as well as physical clearance.
	var approach:Dictionary=track.sample(track.length*.055)
	vista_from=approach.p+approach.frame.y*7.
	var peak:=Vector3.ZERO
	var entered:=false
	for n in track.nodes:
		if n.loop:
			if not entered: vista_targets.append(n.p);peak=n.p
			entered=true
			if n.p.y>peak.y: peak=n.p
		elif entered:
			vista_targets.append(n.p)
			break
	if entered: vista_targets.append(peak)

	for i in range(track.nodes.size()):
		var a:Dictionary=track.nodes[i]
		var b:Dictionary=track.nodes[(i+1)%track.nodes.size()]
		var bounds:=AABB(a.p,Vector3.ZERO).expand(b.p).grow(maxf(a.width,b.width)+18)
		for cell in cells(bounds):
			if not corridor.has(cell): corridor[cell]=[]
			corridor[cell].append(bounds)
	place_landmarks(track)
	# Preserve the mounted landmark artwork in the opening approach composition.
	# Buildings remain on their audited lots; random infill cannot mask these views.
	for building in buildings:
		vista_targets.append(building.center+Vector3.UP*building.height*.72)
	var avenue:Array[Vector3]=[]
	for i in range(15): avenue.append(track.sample(track.length*i*.01).p)
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
			var original_height:=height
			for point:Vector3 in avenue:
				if Vector2(point.x-center.x,point.z-center.z).length()<360.:
					height=maxf(height,point.y-FLOOR+original_height*.55)
			var bounds:=AABB(center-Vector3(width*.5,0,depth*.5),Vector3(width,height+180,depth))
			if not clear(bounds) or occupied(bounds.grow(5)) or blocks_vista(bounds): continue
			buildings.append({"center":center,"width":width,"depth":depth,"height":height,
				"kind":kind,"roof":rng.randi_range(0,5),"roof_height":rng.randf_range(22,55),"antenna":rng.randf_range(35,80),"color":Color(rng.randf(),rng.randf(),rng.randf()),"bounds":bounds})
	place_billboards(track)
	# Air lanes run along the gaps between city lots; reject spans near the ribbon.
	for row in range(-14,15,2):
		for block in range(-3,4):
			var start:=Vector3(block*480,80+posmod(row,3)*85,row*CELL+CELL*.5)
			var bounds:=AABB(start-Vector3(14,5,5),Vector3(508,10,10))
			if not clear(bounds) or occupied(bounds): continue
			routes.append({"start":start,"length":480.0,"direction":1.0 if row%4==0 else -1.0,"bounds":bounds})

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
		if building.get("landmark",false): nearest=vista_from
		var direction:Vector3=nearest-building.center
		var normal:=Vector3(signf(direction.x),0,0) if absf(direction.x)>absf(direction.z) else Vector3(0,0,signf(direction.z))
		var on_x:=absf(normal.x)>.5
		var width:float=(building.depth*.82 if on_x else building.width*.78)*.88
		var height:=width*2.5
		var center_y:=clampf(nearest.y+height*.20,building.center.y+building.height*.15+height*.5,building.center.y+building.height-height*.5-8)
		var position:Vector3=building.center+normal*((building.width*.39 if on_x else building.depth*.41)+.7)
		position.y=center_y
		var frame:=Basis(Vector3.UP.cross(normal),Vector3.UP,normal)
		var transform_value:=Transform3D(frame,position)
		var bounds:AABB=transform_value*AABB(Vector3(-width*.5-.6,-height*.5-.6,-.25),Vector3(width+1.2,height+1.2,.7))
		if not building.bounds.encloses(bounds) or not clear(bounds): continue
		billboards.append({"transform":transform_value,"size":Vector2(width,height),"variant":index%4,"building":index,"bounds":bounds})

func place_landmarks(track:RefCounted)->void:
	# Stage a small opening district before filling random city lots. It follows
	# each seeded ribbon, and each full building still passes the corridor audit.
	for i in range(6):
		var n:Dictionary=track.sample(track.length*[.018,.04,.06,.078,.10,.12][i])
		var side:float=1. if i%2==0 else -1.
		var direction:Vector3=Vector3(n.frame.x.x,0,n.frame.x.z).normalized()*side
		for offset in [100.,140.,180.]:
			var center:Vector3=n.p+direction*(n.width+offset)
			center.y=FLOOR
			var w:=94.+i*5.
			var d:=78.+i*3.
			var h:=maxf(450.+i*65.,n.p.y-FLOOR+260.)
			var bounds:=AABB(center-Vector3(w*.5,0,d*.5),Vector3(w,h+180,d))
			if not clear(bounds) or occupied(bounds.grow(8)) or blocks_vista(bounds): continue
			buildings.append({"center":center,"width":w,"depth":d,"height":h,
				"kind":0,"roof":i%6,"roof_height":44.,"antenna":62.,
				"color":Color(.14+i*.19,.25+i*.14,.55),"bounds":bounds,"landmark":true})
			break

func blocks_vista(bounds:AABB)->bool:
	for target in vista_targets:
		if bounds.grow(24.).intersects_segment(vista_from,target)!=null: return true
	return false
