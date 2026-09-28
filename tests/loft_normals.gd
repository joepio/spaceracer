extends SceneTree
const Ship=preload("res://src/ship.gd")
const Vfx=preload("res://src/weapon_vfx.gd")
var checks:=0
var failures:=0
func check_mesh(node:MeshInstance3D)->void:
	var arrays:=node.mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var bounds:=node.mesh.get_aabb()
	for i in range(0,vertices.size(),3):
		var a:=vertices[i];var b:=vertices[i+1];var c:=vertices[i+2]
		var center:=(a+b+c)/3.
		# Godot front faces are clockwise, independently of vertex normals.
		var outward:=-(b-a).cross(c-a).normalized()
		var expected:=Vector3(center.x,center.y,0.)
		var expected_normals:=[Vector3(a.x,a.y,0.),Vector3(b.x,b.y,0.),Vector3(c.x,c.y,0.)]
		if is_equal_approx(a.z,b.z) and is_equal_approx(a.z,c.z):
			expected=Vector3.FORWARD if is_equal_approx(a.z,bounds.position.z) else Vector3.BACK
			expected_normals=[expected,expected,expected]
		checks+=1
		if outward.dot(expected)<=0. or normals[i].dot(expected_normals[0])<=0. or normals[i+1].dot(expected_normals[1])<=0. or normals[i+2].dot(expected_normals[2])<=0.:
			failures+=1
			if failures<5: push_error("Inward face or shading normal: %s triangle %d"%[node.name,i/3])
func _initialize()->void: call_deferred("run")
func run()->void:
	var holder:=Node3D.new();root.add_child(holder)
	var builder:=Vfx.new();holder.add_child(builder)
	builder.steel=Vfx.material(Color.GRAY)
	var missile:=Node3D.new();holder.add_child(missile);builder.missile_hull(missile)
	for node in missile.get_children():
		if node is MeshInstance3D and node.mesh is ArrayMesh: check_mesh(node)
	# The same loft builds the racers, with open ends and tapered sections.
	check_mesh(Ship.loft(holder,"OpenHull",[Vector3(-3.,.5,.7),Vector3(0.,1.,1.2),Vector3(4.,.05,.1)],builder.steel))
	print("LOFT_NORMAL_TESTS ",checks," triangles, ",failures," failures")
	holder.queue_free();await process_frame;quit(1 if failures else 0)
