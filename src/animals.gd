extends RefCounted
## Huge low-poly wildlife, baked into two colored surfaces per animal.
## No skeletal rigs, textures, physics bodies, or per-frame mesh generation.
var heads:Array[Dictionary]=[]
var placements:Array[Vector3]=[]
var sphere:SphereMesh
var cylinder:CylinderMesh
var surface:SurfaceTool

func shape(mesh:Mesh,at:Vector3,size:Vector3,color:Color,rotation:Basis=Basis.IDENTITY)->void:
	var arrays:=mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var basis:=rotation*Basis.from_scale(size)
	var normal_basis:=basis.inverse().transposed()
	for i in indices:
		surface.set_color(color)
		surface.set_normal((normal_basis*normals[i]).normalized())
		surface.add_vertex(at+basis*vertices[i])

func oval(at:Vector3,size:Vector3,color:Color)->void:
	shape(sphere,at,size,color)

func limb(a:Vector3,b:Vector3,radius:float,color:Color)->void:
	var direction:=(b-a).normalized()
	var rotation:=Basis(Quaternion(Vector3.UP,direction))
	shape(cylinder,(a+b)*.5,Vector3(radius,a.distance_to(b),radius),color,rotation)

func begin_mesh()->void:
	surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func finish_mesh(parent:Node3D,material:Material)->void:
	surface.index()
	var instance:=MeshInstance3D.new()
	instance.mesh=surface.commit()
	instance.material_override=material
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func eyes(at:Vector3,width:float)->void:
	for side in [-1,1]:
		oval(at+Vector3(side*width,0,0),Vector3(.09,.12,.14),Color("172336"))

func elephant(head:bool)->void:
	var blue:=Color("83b8cb")
	var light:=Color("a3d0dc")
	var foot:=Color("bacbd4")
	if not head:
		oval(Vector3(0,3.1,0),Vector3(1.35,1.55,2.1),blue)
		for x in [-.85,.85]:
			for z in [-1.2,1.2]:
				limb(Vector3(x,.25,z),Vector3(x,2.8,z),.47,blue)
				oval(Vector3(x,.25,z-.06),Vector3(.49,.27,.54),foot)
		limb(Vector3(0,3,-1.8),Vector3(.25,1.7,-2.3),.1,blue)
		oval(Vector3(.25,1.6,-2.3),Vector3(.15,.25,.15),Color("547489"))
	else:
		oval(Vector3.ZERO,Vector3(1.04,1.15,1),light)
		for side in [-1,1]:
			oval(Vector3(side*1.08,.05,-.15),Vector3(.72,1.18,.24),blue)
			oval(Vector3(side*1.13,.05,.02),Vector3(.49,.85,.13),Color("b0a7c8"))
			limb(Vector3(side*.65,-.5,.58),Vector3(side*.68,-.8,1.45),.13,Color("fff1c6"))
			limb(Vector3(side*.68,-.8,1.45),Vector3(side*.62,-.58,1.85),.08,Color("fff1c6"))
		eyes(Vector3(0,.15,.7),.72)
		# A curled trunk with overlapping sections, deliberately readable in silhouette.
		var points:=[Vector3(0,-.3,.8),Vector3(0,-1.1,1.1),Vector3(0,-2.05,1.35),Vector3(0,-2.45,1.8),Vector3(0,-2.1,2.3)]
		for i in range(points.size()-1):
			limb(points[i],points[i+1],.31-i*.045,light)
			oval(points[i+1],Vector3.ONE*(.30-i*.045),light)

func giraffe(head:bool)->void:
	var gold:=Color("f8c568")
	var spot:=Color("ae683e")
	if not head:
		oval(Vector3(0,3.5,0),Vector3(.8,1.05,1.65),gold)
		for x in [-.55,.55]:
			for z in [-1.05,1.05]:
				limb(Vector3(x,.15,z),Vector3(x,3.3,z),.17,gold)
				oval(Vector3(x,.15,z+.06),Vector3(.22,.18,.3),spot)
		limb(Vector3(0,3.8,1),Vector3(0,7.3,1.85),.42,gold)
		limb(Vector3(0,4, .64),Vector3(0,7.25,1.5),.11,spot)
		limb(Vector3(0,3.8,-1.5),Vector3(0,2.4,-1.9),.075,gold)
		oval(Vector3(0,2.25,-1.9),Vector3(.17,.3,.17),spot)
		for side in [-1,1]:
			for i in range(8):
				var y:=4.1+i*.39
				oval(Vector3(side*.385,y,1.04+i*.097),Vector3(.065,.15,.22),spot)
			for i in range(12):
				var a:=float(i)/12*TAU
				oval(Vector3(side*.74,3.5+sin(a)*.54,cos(a)*1.15),Vector3(.1,.2,.26),spot)
	else:
		oval(Vector3(0,0,.05),Vector3(.44,.48,.68),gold)
		oval(Vector3(0,-.1,.68),Vector3(.42,.28,.51),gold.lightened(.16))
		for side in [-1,1]:
			oval(Vector3(side*.6,.22,-.12),Vector3(.32,.14,.21),gold)
			limb(Vector3(side*.23,.32,-.13),Vector3(side*.27,.92,-.2),.065,gold)
			oval(Vector3(side*.27,.92,-.2),Vector3.ONE*.12,spot)
		eyes(Vector3(0,.13,.23),.4)

func flamingo(head:bool)->void:
	var pink:=Color("ff83b4")
	var dark:=Color("f04589")
	if not head:
		oval(Vector3(0,3.4,0),Vector3(.65,.75,1.2),pink)
		for side in [-1,1]:
			oval(Vector3(side*.52,3.48,-.15),Vector3(.2,.48,.91),dark)
		limb(Vector3(-.25,.13,.22),Vector3(-.25,3.2,0),.07,dark)
		limb(Vector3(.25,3.2,0),Vector3(.25,1.65,-.2),.07,dark)
		limb(Vector3(.25,1.65,-.2),Vector3(.25,2.45,-1.15),.065,dark)
		oval(Vector3(-.25,.1,.4),Vector3(.27,.09,.42),dark)
		var points:=[Vector3(0,3.6,.8),Vector3(0,4.4,1.1),Vector3(0,4.95,.75),Vector3(0,5.55,.78),Vector3(0,5.9,1.18)]
		for i in range(points.size()-1):
			limb(points[i],points[i+1],.17,pink)
			oval(points[i+1],Vector3.ONE*.18,pink)
	else:
		oval(Vector3.ZERO,Vector3(.29,.32,.37),pink)
		limb(Vector3(0,-.06,.26),Vector3(0,-.15,.68),.17,Color("ffe3bd"))
		limb(Vector3(0,-.15,.68),Vector3(0,-.45,.8),.14,Color("25263b"))
		eyes(Vector3(0,.06,.15),.25)

func build(parent:Node3D,track:RefCounted)->void:
	sphere=SphereMesh.new()
	sphere.radius=1
	sphere.height=2
	sphere.radial_segments=12
	sphere.rings=6
	cylinder=CylinderMesh.new()
	cylinder.top_radius=1
	cylinder.bottom_radius=1
	cylinder.height=1
	cylinder.radial_segments=8
	cylinder.rings=1
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=.83
	# Vertex-colored surface gives all body parts one draw call.
	var kinds:=["giraffe","elephant","flamingo","giraffe","elephant","flamingo"]
	var progress:=[.115,.32,.46,.61,.79,.94]
	for i in range(kinds.size()):
		var center:Vector3=track.base_position(progress[i])
		var outward:=Vector3(center.x,0,center.z).normalized()
		var position:=center+outward*380
		var clearance:=520.0 if kinds[i]=="elephant" else 320.0
		# Keep the entire silhouette clear of every seed's racing ribbon.
		for attempt in range(12):
			var clear:=true
			for n in track.nodes:
				if Vector2(position.x-n.p.x,position.z-n.p.z).length()<clearance:
					clear=false
					break
			if clear: break
			position+=outward*85
		position.y=-145
		placements.append(position)
		var root:=Node3D.new()
		parent.add_child(root)
		root.position=position
		root.rotation.y=atan2(-outward.x,-outward.z)+(.45 if i%2==0 else -.45)
		root.scale=Vector3.ONE*(86 if kinds[i]=="giraffe" else (105 if kinds[i]=="elephant" else 100))
		begin_mesh()
		call(kinds[i],false)
		finish_mesh(root,material)
		var head:=Node3D.new()
		root.add_child(head)
		head.position={"giraffe":Vector3(0,7.35,1.85),"elephant":Vector3(0,3.7,1.75),"flamingo":Vector3(0,5.9,1.18)}[kinds[i]]
		begin_mesh()
		call(kinds[i],true)
		finish_mesh(head,material)
		heads.append({"node":head,"phase":i*1.7})
		# Small terraced sanctuary under each giant; grounds the silhouette in the water.
		for tier in range(3):
			var island:=CylinderMesh.new()
			island.top_radius=250-tier*22
			island.bottom_radius=265-tier*22
			island.height=18
			island.radial_segments=16
			var base:=MeshInstance3D.new()
			base.mesh=island
			var stone:=StandardMaterial3D.new()
			stone.albedo_color=Color("366c70") if tier==2 else Color("243e56")
			stone.roughness=.9
			base.material_override=stone
			base.position=position+Vector3(0,-45+tier*18,0)
			parent.add_child(base)

func animate(time:float)->void:
	for head in heads:
		head.node.rotation=Vector3(sin(time*.42+head.phase)*.055,sin(time*.27+head.phase)*.14,0)
