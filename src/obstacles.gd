extends RefCounted
## Swept craft-volume checks against actual scenery parts, not entire city lots.
const Cells=preload("res://src/city_layout.gd")
var buckets:Dictionary={}
var shapes:Array[Dictionary]=[]
var moving:Array[Transform3D]=[]
var terrain:RefCounted
var traffic:RefCounted
var ground_traffic:RefCounted

func add_box(frame:Transform3D,bounds:AABB=AABB(Vector3.ONE*-.5,Vector3.ONE))->void:
	var world:AABB=frame*bounds
	var shape:={"inverse":frame.affine_inverse(),"bounds":bounds,"scale":frame.basis.get_scale().abs()}
	var id:=shapes.size()
	shapes.append(shape)
	for cell in Cells.cells(world.grow(6.)):
		if not buckets.has(cell): buckets[cell]=[]
		buckets[cell].append(id)

func add_visual_boxes(node:Node)->void:
	if node is MeshInstance3D and node.mesh is BoxMesh and (node.layers&5)!=0 and not node.get_meta("track_surface",false):
		add_box(node.global_transform,node.mesh.get_aabb())
	for child in node.get_children(): add_visual_boxes(child)

func hit(from:Vector3,to:Vector3,radius:float=3.6)->Variant:
	var contact:=trace(from,to,radius)
	return null if contact.is_empty() else contact.position

static func box_contact(inverse:Transform3D,bounds:AABB,from:Vector3,to:Vector3)->Dictionary:
	var origin:Vector3=inverse*from
	var end:Vector3=inverse*to
	var inside:=bounds.has_point(origin)
	var contact:Variant=origin if inside else bounds.intersects_segment(origin,end)
	if contact==null: return {}
	var point:Vector3=contact
	var normal:=Vector3.ZERO
	var closest:=INF
	for axis in range(3):
		for side in [-1.,1.]:
			var face:float=bounds.position[axis] if side<0 else bounds.end[axis]
			var distance:=absf(point[axis]-face)
			if distance<closest:
				closest=distance;normal=Vector3.ZERO;normal[axis]=side
	# Also depenetrate fragments that start inside an expanded collision box.
	if inside: point+=normal*closest
	return {"position":inverse.affine_inverse()*point,"normal":(inverse.basis.transposed()*normal).normalized()}

func trace(from:Vector3,to:Vector3,radius:float=3.6)->Dictionary:
	var seen:Dictionary={}
	var nearest:Dictionary={}
	var best:=INF
	if terrain!=null:
		nearest=terrain.trace(from,to,radius)
		if not nearest.is_empty(): best=from.distance_squared_to(nearest.position)
	if traffic!=null:
		var contact:Dictionary=traffic.trace(from,to,radius)
		if not contact.is_empty() and from.distance_squared_to(contact.position)<best:
			nearest=contact;best=from.distance_squared_to(contact.position)
	if ground_traffic!=null:
		var contact:Dictionary=ground_traffic.trace(from,to,radius)
		if not contact.is_empty() and from.distance_squared_to(contact.position)<best:
			nearest=contact;best=from.distance_squared_to(contact.position)
	for cell in Cells.cells(AABB(from,Vector3.ZERO).expand(to).grow(radius)):
		for id in buckets.get(cell,[]):
			if seen.has(id): continue
			seen[id]=true
			var shape:Dictionary=shapes[id]
			var padding:Vector3=Vector3.ONE*radius/shape.scale
			var bounds:AABB=AABB(shape.bounds.position-padding,shape.bounds.size+padding*2.)
			var contact:=box_contact(shape.inverse,bounds,from,to)
			if contact.is_empty(): continue
			var distance:=from.distance_squared_to(contact.position)
			if distance<best: best=distance;nearest=contact
	for frame in moving:
		var bounds:AABB=frame*AABB(Vector3.ONE*-.5,Vector3.ONE)
		if bounds.grow(radius).intersects_segment(from,to)==null and not bounds.grow(radius).has_point(from): continue
		var inverse:=frame.affine_inverse()
		var padding:=Vector3.ONE*radius/frame.basis.get_scale().abs()
		var local:=AABB(Vector3.ONE*-.5-padding,Vector3.ONE+padding*2.)
		var contact:=box_contact(inverse,local,from,to)
		if not contact.is_empty():
			var distance:=from.distance_squared_to(contact.position)
			if distance<best: best=distance;nearest=contact
	return nearest
