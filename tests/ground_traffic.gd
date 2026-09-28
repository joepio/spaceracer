extends SceneTree
const Ground=preload("res://src/ground_traffic.gd")
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	for seed_value in [31,145]:
		var track=load("res://src/track.gd").new(seed_value)
		var layout=load("res://src/city_layout.gd").new(track)
		var parent:=Node3D.new();root.add_child(parent)
		var ground:=Ground.new();ground.build(parent,layout,seed_value)
		print("GROUND seed=",seed_value," buildings=",layout.buildings.size()," podiums=",layout.podiums.size()," routes=",ground.routes.size()," cars=",ground.cars.size()," batches=",ground.renderers.size())
		check(ground.cars.size()>1000,"Ground streets carry substantial traffic")
		var unique:Dictionary={}
		for renderer in ground.renderers:
			var mesh:Mesh=renderer.multimesh.mesh
			if unique.has(mesh): continue
			unique[mesh]=true
			var a:Array=mesh.surface_get_arrays(0)
			check(a[Mesh.ARRAY_INDEX].size()/3<=180,"Ground cars stay below 180 triangles")
			for i in range(0,a[Mesh.ARRAY_INDEX].size(),3):
				var x:int=a[Mesh.ARRAY_INDEX][i];var y:int=a[Mesh.ARRAY_INDEX][i+1];var z:int=a[Mesh.ARRAY_INDEX][i+2]
				check((a[Mesh.ARRAY_VERTEX][z]-a[Mesh.ARRAY_VERTEX][x]).cross(a[Mesh.ARRAY_VERTEX][y]-a[Mesh.ARRAY_VERTEX][x]).dot(a[Mesh.ARRAY_NORMAL][x])>0.,"Ground car faces and lenses point outward")
		check(unique.size()==4,"Only four shared vehicle meshes")
		for route in ground.routes:
			for id in route.cars:
				var car:Dictionary=ground.cars[id]
				var pose:=ground.car_frame(car)
				check(route.bounds.has_point(pose.origin),"Car stays inside its culling bounds")
				check(absf(pose.origin.y-Ground.HEIGHT)<.001,"Cars stay grounded")
		for time in [0.,5.3,100.]:
			ground.animate(time)
			for id in range(0,ground.cars.size(),maxi(1,ground.cars.size()/40)):
				var car:Dictionary=ground.cars[id];var pose:=ground.car_frame(car)
				var bounds:=pose*car_bounds(car.variant)
				var collision:=false
				for b in layout.buildings+layout.podiums:
					if bounds.intersects(b.bounds) and intersects_lot(pose,car_bounds(car.variant),b.bounds): collision=true;break
				check(layout.clear(bounds) and not collision,"Actual car clears buildings and racing ribbon")
				check(not ground.trace(pose.origin-Vector3.UP*6.,pose.origin+Vector3.UP*6.,.1).is_empty(),"Car can be hit while turning or driving")
		var car:Dictionary=ground.cars[0];var pose:=ground.car_frame(car)
		ground.animate(100.);check(ground.car_frame(car).is_equal_approx(pose),"Paused time freezes street traffic")
		check(ground.trace(Vector3(0,20,0),Vector3(10,20,0),4.).is_empty(),"Elevated racing avoids ground collision work")
		parent.free()
	for corner in range(4):
		for offset in [0.,88.]:
			var t:float=corner*Ground.SEGMENT+offset
			var a:=Ground.local_frame(t-.001);var b:=Ground.local_frame(t+.001)
			check(a.origin.distance_to(b.origin)<.003 and a.basis.z.dot(b.basis.z)>.999,"Turn transitions and lap seams are smooth")
	print("GROUND_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
func car_bounds(variant:int)->AABB:
	var size:Vector3=Ground.Traffic.SIZES[variant]
	return AABB(Vector3(-size.x*.56,-.75,-size.z*.5-.1),Vector3(size.x*1.12,size.y+.15,size.z+.2))

func intersects_lot(pose:Transform3D,local:AABB,lot:AABB)->bool:
	var delta:Vector3=lot.get_center()-pose*local.get_center()
	var half:Vector3=local.size*.5*Ground.SCALE
	var axes:=pose.basis.orthonormalized()
	for axis in [Vector3.RIGHT,Vector3.BACK,axes.x,axes.z]:
		var extent:float=half.x*absf(axis.dot(axes.x))+half.z*absf(axis.dot(axes.z))+lot.size.x*.5*absf(axis.x)+lot.size.z*.5*absf(axis.z)
		if absf(delta.dot(axis))>extent: return false
	return true
