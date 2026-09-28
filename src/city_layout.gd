extends RefCounted
## Deterministic city lots with a conservative 3D swept-road exclusion volume.
const CELL:=120.0
const FLOOR:=-180.0
var corridor:Dictionary={}
var buildings:Array[Dictionary]=[]
var podiums:Array[Dictionary]=[]
var occupied_cells:Dictionary={}
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
		if a.feature in ["jump","flight"]:
			# Reserve airspace above and beside the flight corridor, including the
			# run-up and landing. Buildings and traffic use this same exclusion.
			bounds=bounds.grow(35.).expand(a.p+Vector3.UP*140.)
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
			if rng.randf()<.035: continue
			var block_center:=Vector3(x*CELL,FLOOR,z*CELL)
			var pattern:=rng.randf()
			var plots:Array[Vector4]=[] # local x/z, width/depth: always inside the block
			if pattern<.16:
				plots.append(Vector4(0,0,94,94))
			elif pattern<.5:
				for side in [-1.,1.]:
					plots.append(Vector4(side*25.,0,44,94) if (x+z)%2==0 else Vector4(0,side*25.,94,44))
			else:
				for side in [-1.,1.]:
					for end in [-1.,1.]: plots.append(Vector4(side*25.,end*25.,44,44))
			var before:=buildings.size()
			for plot in plots:
				var kind:=rng.randi_range(0,7)
				var width:=plot.z;var depth:=plot.w
				var height:=rng.randf_range(150,530) if plots.size()>1 else rng.randf_range(280,740)
				if kind==6: height*=.7
				elif kind==3:
					width=minf(width,rng.randf_range(26,36));depth=minf(depth,width)
				if rng.randf()<.08: height=rng.randf_range(650,920)
				var center:=block_center+Vector3(plot.x,0,plot.y)
				var original_height:=height
				for point:Vector3 in avenue:
					if Vector2(point.x-center.x,point.z-center.z).length()<360.:
						height=maxf(height,point.y-FLOOR+original_height*.55)
				var bounds:=AABB(center-Vector3(width*.5,0,depth*.5),Vector3(width,height+180,depth))
				if not clear(bounds) or occupied(bounds.grow(1.)) or blocks_vista(bounds): continue
				add_building({"center":center,"width":width,"depth":depth,"height":height,"block":Vector2i(x,z),
					"kind":kind,"roof":rng.randi_range(0,5),"roof_height":rng.randf_range(22,55),"antenna":rng.randf_range(35,80),"color":Color(rng.randf(),rng.randf(),rng.randf()),"bounds":bounds})
			if buildings.size()>before and plots.size()>1:
				var base_height:=rng.randf_range(12.,24.)
				var bounds:=AABB(block_center-Vector3(48,0,48),Vector3(96,base_height,96))
				if clear(bounds) and not blocks_vista(bounds):
					podiums.append({"center":block_center+Vector3.UP*base_height*.5,"size":bounds.size,"bounds":bounds,"color":Color(.3,.42,.52)})
					register_lot(bounds)
	place_billboards(track)
	# Opposing streams occupy separate lanes, stacked through the city. Merge
	# consecutive clear blocks so cars do not wrap at every street intersection.
	for row in range(-17,18):
		for level in range(3):
			for direction in [-1.,1.]:
				var start:=Vector3.ZERO
				var length:=0.
				for block in range(-9,10):
					var point:=Vector3(block*240.,-35.+level*145.,row*CELL+60.+direction*8.)
					var bounds:=AABB(point-Vector3(9,4,4),Vector3(258,8,8))
					var available:bool=block<9 and clear(bounds) and not occupied(bounds)
					if available:
						if length==0.: start=point
						length+=240.
					elif length>0.:
						routes.append({"start":start,"length":length,"direction":direction,
							"bounds":AABB(start-Vector3(9,4,4),Vector3(length+18.,8,8))})
						length=0.

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
	for cell in cells(bounds):
		for lot:AABB in occupied_cells.get(cell,[]):
			if bounds.intersects(lot): return true
	return false

func register_lot(bounds:AABB)->void:
	for cell in cells(bounds):
		if not occupied_cells.has(cell): occupied_cells[cell]=[]
		occupied_cells[cell].append(bounds)

func add_building(building:Dictionary)->void:
	buildings.append(building);register_lot(building.bounds)

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
		billboards.append({"transform":transform_value,"size":Vector2(width,height),"variant":index%4,"building":index,"bounds":bounds,"priority":distance if not building.get("landmark",false) else -1.})
	billboards.sort_custom(func(a:Dictionary,b:Dictionary):return a.priority<b.priority)
	if billboards.size()>64: billboards.resize(64)

func place_landmarks(track:RefCounted)->void:
	# Stage a small opening district before filling random city lots. It follows
	# each seeded ribbon, and each full building still passes the corridor audit.
	for i in range(6):
		var n:Dictionary=track.sample(track.length*[.018,.04,.06,.078,.10,.12][i])
		var side:float=1. if i%2==0 else -1.
		var direction:Vector3=Vector3(n.frame.x.x,0,n.frame.x.z).normalized()*side
		for offset in [100.,140.,180.]:
			var center:Vector3=n.p+direction*(n.width+offset)
			center.x=roundf(center.x/CELL)*CELL;center.z=roundf(center.z/CELL)*CELL
			center.y=FLOOR
			var w:=88.+(i%3)*3.
			var d:=82.+(i%2)*10.
			var h:=maxf(450.+i*65.,n.p.y-FLOOR+260.)
			var bounds:=AABB(center-Vector3(w*.5,0,d*.5),Vector3(w,h+180,d))
			if not clear(bounds) or occupied(bounds.grow(8)) or blocks_vista(bounds): continue
			add_building({"center":center,"width":w,"depth":d,"height":h,
				"kind":0,"roof":i%6,"roof_height":44.,"antenna":62.,
				"color":Color(.14+i*.19,.25+i*.14,.55),"bounds":bounds,"landmark":true,"block":Vector2i(roundi(center.x/CELL),roundi(center.z/CELL))})
			break

func blocks_vista(bounds:AABB)->bool:
	for target in vista_targets:
		if bounds.grow(24.).intersects_segment(vista_from,target)!=null: return true
	return false
