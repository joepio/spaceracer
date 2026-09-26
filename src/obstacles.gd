extends RefCounted
## Swept craft-volume checks against actual scenery parts, not entire city lots.
const Cells=preload("res://src/city_layout.gd")
var buckets:Dictionary={}
var shapes:Array[Dictionary]=[]
var moving:Array[Transform3D]=[]

func add_box(frame:Transform3D,bounds:AABB=AABB(Vector3.ONE*-.5,Vector3.ONE))->void:
	var world:AABB=frame*bounds
	var shape:={"inverse":frame.affine_inverse(),"bounds":bounds,"scale":frame.basis.get_scale().abs()}
	var id:=shapes.size()
	shapes.append(shape)
	for cell in Cells.cells(world.grow(6.)):
		if not buckets.has(cell): buckets[cell]=[]
		buckets[cell].append(id)

func add_visual_boxes(node:Node)->void:
	if node is MeshInstance3D and node.mesh is BoxMesh and (node.layers&5)!=0:
		add_box(node.global_transform,node.mesh.get_aabb())
	for child in node.get_children(): add_visual_boxes(child)

func hit(from:Vector3,to:Vector3,radius:float=3.6)->Variant:
	var seen:Dictionary={}
	var nearest:Variant=null
	var best:=INF
	for cell in Cells.cells(AABB(from,Vector3.ZERO).expand(to).grow(radius)):
		for id in buckets.get(cell,[]):
			if seen.has(id): continue
			seen[id]=true
			var shape:Dictionary=shapes[id]
			var padding:Vector3=Vector3.ONE*radius/shape.scale
			var bounds:AABB=AABB(shape.bounds.position-padding,shape.bounds.size+padding*2.)
			var local_from:Vector3=shape.inverse*from
			var local_to:Vector3=shape.inverse*to
			var contact:Variant=local_from if bounds.has_point(local_from) else bounds.intersects_segment(local_from,local_to)
			if contact==null: continue
			var point:Vector3=shape.inverse.affine_inverse()*contact
			var distance:=from.distance_squared_to(point)
			if distance<best: best=distance;nearest=point
	for frame in moving:
		var bounds:AABB=frame*AABB(Vector3.ONE*-.5,Vector3.ONE)
		if bounds.grow(radius).intersects_segment(from,to)==null and not bounds.grow(radius).has_point(from): continue
		var inverse:=frame.affine_inverse()
		var padding:=Vector3.ONE*radius/frame.basis.get_scale().abs()
		var local:=AABB(Vector3.ONE*-.5-padding,Vector3.ONE+padding*2.)
		var origin:Vector3=inverse*from
		var contact:Variant=origin if local.has_point(origin) else local.intersects_segment(origin,inverse*to)
		if contact!=null:
			var point:Vector3=frame*contact
			var distance:=from.distance_squared_to(point)
			if distance<best: best=distance;nearest=point
	return nearest
