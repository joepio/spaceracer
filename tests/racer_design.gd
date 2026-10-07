extends SceneTree
const Ship=preload("res://src/ship.gd")
const Race=preload("res://src/race.gd")
const Vfx=preload("res://src/weapon_vfx.gd")
var checks:=0
var failures:=0
var triangles:=0
var surfaces:=0
var bounds:=AABB()
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func inspect(node:Node3D,frame:Transform3D)->void:
	frame=frame*node.transform
	if node is MeshInstance3D:
		bounds=bounds.merge(frame*node.mesh.get_aabb())
		for index in range(node.mesh.get_surface_count()):
			surfaces+=1
			var arrays:Array=node.mesh.surface_get_arrays(index)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			triangles+=(indices.size() if not indices.is_empty() else vertices.size())/3
			for i in range(vertices.size()): check(vertices[i].is_finite() and normals[i].is_finite(),"Finite mesh coordinates and normals")
			var count:int=indices.size() if not indices.is_empty() else vertices.size()
			for t in range(0,count,3):
				var a:int=indices[t] if not indices.is_empty() else t
				var b:int=indices[t+1] if not indices.is_empty() else t+1
				var c:int=indices[t+2] if not indices.is_empty() else t+2
				var geometric:Vector3=(vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
				if geometric.length_squared()>.00000001: check(geometric.dot(normals[a]+normals[b]+normals[c])>0.,"Surface normals agree with outward clockwise faces")
	for child in node.get_children():
		if child is Node3D: inspect(child,frame)
func _initialize()->void: call_deferred("run")
func run()->void:
	var designs:={}
	for variant in range(Ship.Design.VARIANTS.size()):
		triangles=0;surfaces=0;bounds=AABB()
		var ship:=Ship.build(Color("bf3334"),variant);root.add_child(ship)
		designs[ship.get_meta("design")]=true
		# Physical mesh budget excludes the existing animated exhaust and optical effects.
		for name_value in ["Body","Canopy","Nacelle-1","Nacelle1","Wing-1","Wing1","WingControlL","WingControlR","RudderL","RudderR","Nozzle-1","Nozzle1","Airbrake-1","Airbrake1"]:
			inspect(ship.get_node(name_value),Transform3D.IDENTITY)
		for name_value in ["Winglet-1","Winglet1","Canard-1","Canard1","Spoiler","Pylon-1","Pylon1","Endplate-1","Endplate1"]:
			if ship.has_node(name_value): inspect(ship.get_node(name_value),Transform3D.IDENTITY)
		print("RACER_GEOMETRY ",ship.get_meta("design")," triangles=",triangles," surfaces=",surfaces," bounds=",bounds)
		check(triangles<9000,"Detailed racer stays below 9000 physical triangles")
		check(surfaces<=65,"Physical surfaces stay within per-vehicle draw budget")
		check(bounds.size.x<=9.5 and bounds.position.z>=-4.1 and bounds.end.z<=5.1,"Every airframe retains the gameplay collision envelope: %s"%ship.get_meta("design"))
		ship.queue_free()
	check(designs.size()==Ship.Design.VARIANTS.size(),"Each airframe family is distinct")
	var race:=Race.new([{"slot":0},{"slot":1}],31);var p:Dictionary=race.racers[0]
	var vfx:=Vfx.new();root.add_child(vfx);vfx.configure(race)
	for kind in Race.Weapons.NAMES:
		p.weapon=kind;p.drone_time=0.;p.warp_time=0.;p.warp_fx=0.;vfx.update()
		var visible:=1 if vfx.turrets[0].visible else 0
		for mount in vfx.mounts[0].values():
			if mount.visible: visible+=1;check(mount.position.distance_to(Race.Weapons.pose(race,p)*Ship.Design.SOCKET)<.001,"All equipment uses the same dorsal hardpoint")
		check(visible==1,"Exactly one mounted module per equipped item")
		p.drone_time=2.;vfx.update()
		check(vfx.turrets[0].visible,"Active sentry owns the socket")
		for mount in vfx.mounts[0].values(): check(not mount.visible,"Queued item cannot overlap active hardware")
	p.drone_time=0.;p.weapon="railgun";p.warp_time=2.;p.warp_fx=1.;vfx.update()
	check(vfx.mounts[0].warp.visible and not vfx.mounts[0].railgun.visible,"Active warp cassette hides queued hardware")
	p.warp_time=0.;p.warp_fx=0.;vfx.update()
	check(vfx.mounts[0].railgun.visible,"Stored item becomes mounted after active effect finishes")
	p.crashed=true;vfx.update()
	for mount in vfx.mounts[0].values(): check(not mount.visible,"Crash removes mounted hardware")
	check(not vfx.turrets[0].visible,"Crash removes sentry")
	vfx.queue_free();await process_frame
	print("RACER_DESIGN_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
