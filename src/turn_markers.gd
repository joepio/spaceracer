extends RefCounted
## Road-mounted warning chevrons. Three shared meshes, no extra lights.
const Track=preload("res://src/track.gd")

static func quad(surface:SurfaceTool,frame:Transform3D,a:Vector3,b:Vector3,c:Vector3,d:Vector3)->void:
	var normal:=frame.basis*((b-a).cross(c-a).normalized())
	for point in [a,b,c,a,c,d]:
		surface.set_normal(normal)
		surface.add_vertex(frame*point)

static func stroke(surface:SurfaceTool,frame:Transform3D,a:Vector2,b:Vector2,width:float)->void:
	var edge:Vector2=(b-a).orthogonal().normalized()*width*.5
	quad(surface,frame,Vector3(a.x-edge.x,a.y-edge.y,.08),Vector3(b.x-edge.x,b.y-edge.y,.08),Vector3(b.x+edge.x,b.y+edge.y,.08),Vector3(a.x+edge.x,a.y+edge.y,.08))

static func build(parent:Node3D,track:RefCounted)->void:
	var panel:=SurfaceTool.new();panel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var neon:=SurfaceTool.new();neon.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mounts:=SurfaceTool.new();mounts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=0
	# Read the first significant bend ahead, rather than a later opposite S-bend.
	for distance in range(0,int(track.length),72):
		var n:Dictionary=track.sample(distance)
		if n.loop or n.tunnel or n.air_gap or n.feature!="ribbon" or not n.rails: continue
		var turn:=0.
		for ahead in range(0,321,24):
			var next:Dictionary=track.sample(distance+ahead)
			if next.loop or next.air_gap or next.feature!="ribbon": break
			if absf(next.curve)>.0035:
				turn=signf(next.curve)
				break
		if turn==0.: continue
		# Positive track lateral is the driver's right; panels sit outside the bend.
		var frame:=Transform3D(Basis(-n.frame.x,n.frame.y,-n.frame.z),Track.point(n,-turn*(n.width+8.),6.))
		if track.obstacles: track.obstacles.add_box(frame,AABB(Vector3(-6,-2.8,-.1),Vector3(12,5.6,.2)))
		quad(panel,frame,Vector3(-6,-2.8,0),Vector3(6,-2.8,0),Vector3(6,2.8,0),Vector3(-6,2.8,0))
		for x in [-3.6,0.,3.6]:
			stroke(neon,frame,Vector2(x-turn*1.1,1.8),Vector2(x+turn*1.1,0),.48)
			stroke(neon,frame,Vector2(x+turn*1.1,0),Vector2(x-turn*1.1,-1.8),.48)
		for x in [-4.,4.]:
			quad(mounts,frame,Vector3(x-.22,-6,0),Vector3(x+.22,-6,0),Vector3(x+.22,-2.8,0),Vector3(x-.22,-2.8,0))
		count+=1
	if count==0: return
	for entry in [[panel,Color("101c27"),0.],[neon,Color("ffbe50"),3.5],[mounts,Color("344955"),0.]]:
		var material:=StandardMaterial3D.new()
		material.albedo_color=entry[1]
		material.roughness=.7
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		if entry[2]>0:
			material.emission_enabled=true
			material.emission=entry[1]
			material.emission_energy_multiplier=entry[2]
		var mesh:=MeshInstance3D.new()
		mesh.mesh=entry[0].commit();mesh.material_override=material
		mesh.layers=4
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mesh)
	parent.set_meta("turn_marker_count",count)
