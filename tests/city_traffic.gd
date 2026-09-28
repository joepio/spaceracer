extends SceneTree
const Traffic=preload("res://src/city_traffic.gd")
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var track=load("res://src/track.gd").new(31)
	var layout=load("res://src/city_layout.gd").new(track)
	var parent:=Node3D.new();root.add_child(parent)
	var traffic:=Traffic.new();traffic.build(parent,layout,31)
	print("TRAFFIC cars=",traffic.cars.size()," lanes=",traffic.routes.size()," batches=",traffic.batches.size())
	check(traffic.cars.size()>1500,"City has continuous substantial traffic")
	check(traffic.batches.size()<=96,"Traffic uses a bounded set of corridor batches")
	var shared:Dictionary={}
	for data in traffic.batches:
		if shared.has(data.mesh): continue
		shared[data.mesh]=true
		check(data.mesh.get_surface_count()==1,"Body, glass and lamps share one surface")
		var a:=data.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
		var uv:PackedVector2Array=a[Mesh.ARRAY_TEX_UV2];var indices:PackedInt32Array=a[Mesh.ARRAY_INDEX]
		check(indices.size()/3<250,"Traffic silhouette stays below 250 triangles")
		for i in range(0,indices.size(),3):
			var x:=indices[i];var y:=indices[i+1];var z:=indices[i+2]
			check((vertices[z]-vertices[x]).cross(vertices[y]-vertices[x]).dot(normals[x])>0.,"Traffic triangles face outwards")
		for i in range(vertices.size()):
			if uv[i].x==2.: check(vertices[i].z>0.,"White lamps face forward")
			if uv[i].x==3.: check(vertices[i].z<0.,"Red lamps face backwards")
	check(shared.size()==4,"All corridor batches share four meshes")
	for time in [0.,3.7,100.,1000.]:
		traffic.animate(time)
		for route in traffic.routes:
			for id in route.cars:
				var car:Dictionary=traffic.cars[id];var frame:=traffic.car_frame(car)
				check(route.bounds.has_point(frame.origin),"Animated car remains inside audited air lane")
				check(frame.basis.z.x*route.direction>.99,"Car faces travel direction")
	var car:Dictionary=traffic.cars[0];traffic.animate(2.)
	var frame:=traffic.car_frame(car)
	var contact:=traffic.trace(frame.origin-frame.basis.z*25.,frame.origin+frame.basis.z*25.,1.)
	check(not contact.is_empty(),"Swept flight collision hits an animated traffic car")
	check(traffic.trace(Vector3(0,2000,0),Vector3(10,2000,0),3.).is_empty(),"Empty air has no phantom cars")
	traffic.animate(2.);check(traffic.car_frame(car).is_equal_approx(frame),"Paused clock freezes visual and collision poses")
	check(traffic.material.get_shader_parameter("traffic_time")==2.,"Shader and collision clock agree")
	# Query the cars at both ends of every lane, across several wrap cycles.
	for time in [0.,17.3,819.]:
		traffic.animate(time)
		for route in traffic.routes:
			for id in [route.cars[0],route.cars[-1]]:
				var pose:=traffic.car_frame(traffic.cars[id])
				check(not traffic.trace(pose.origin-Vector3.UP*12.,pose.origin+Vector3.UP*12.,.5).is_empty(),"Indexed collision catches lane ends and phase wrap")
	parent.free();print("TRAFFIC_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
