extends RefCounted
## Opening district: visible light fixtures and static scene reflections.
const Track=preload("res://src/track.gd")
var probes:Array[ReflectionProbe]=[]
var fixtures:Array[Dictionary]=[]
var lights:Array[OmniLight3D]=[]

func build(parent:Node3D,track:RefCounted)->void:
	var metal:=StandardMaterial3D.new()
	metal.albedo_color=Color("29333f")
	metal.metallic=.65
	metal.roughness=.28
	var white:=StandardMaterial3D.new()
	white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color=Color("c4e4ff")
	# Twenty-four fixtures across roughly the opening kilometre, spaced in metres.
	var limit:=minf(track.length*.12,1250.)
	for station in range(12):
		var n:Dictionary=track.sample(25.+station*limit/12.)
		if n.loop or n.tunnel: continue
		for side in [-1,1]:
			var frame:=Transform3D(n.frame,n.p)
			var x:float=side*(n.width+9.)
			var bounds:AABB=frame*AABB(Vector3(x-1.5,-2,-1.5),Vector3(3,21,3))
			if not fixture_clear(bounds,track): continue
			var stand:=Node3D.new()
			parent.add_child(stand)
			stand.transform=frame
			piece(stand,Vector3(x,7.5,0),Vector3(.75,19.,.75),metal)
			piece(stand,Vector3(x,17.8,0),Vector3(2.7,.6,2.7),metal)
			piece(stand,Vector3(x,17.35,0),Vector3(2.35,.16,2.35),white)
			var light:=OmniLight3D.new()
			stand.add_child(light)
			light.position=Vector3(x,16.8,0)
			light.light_color=Color("b9d9ff") if station%3!=1 else Color("ffe0b4")
			light.light_energy=3.2
			light.light_specular=.75
			light.omni_range=67.
			light.omni_attenuation=1.4
			light.shadow_enabled=false
			lights.append(light)
			fixtures.append({"bounds":bounds,"transform":frame,"x":x})
	# Capture the real static scene, excluding racers and flying traffic (layer 2).
	# Captures are shared by every player view and never refreshed during driving.
	for u in [.025,.075,.115]:
		var n:Dictionary=track.sample(track.length*u)
		var probe:=ReflectionProbe.new()
		probe.name="DistrictReflection%d"%probes.size()
		probe.position=n.p+Vector3.UP*18
		probe.size=Vector3(660,440,660)
		probe.max_distance=1100.
		probe.blend_distance=90.
		probe.intensity=3.2
		probe.cull_mask=1
		probe.reflection_mask=6
		probe.box_projection=true
		probe.update_mode=ReflectionProbe.UPDATE_ONCE
		probe.ambient_mode=ReflectionProbe.AMBIENT_ENVIRONMENT
		parent.add_child(probe)
		probes.append(probe)

static func fixture_clear(bounds:AABB,track:RefCounted)->bool:
	for i in range(track.nodes.size()):
		var a:Dictionary=track.nodes[i]
		var b:Dictionary=track.nodes[(i+1)%track.nodes.size()]
		var frame:=Transform3D(a.frame,a.p)
		var local:AABB=frame.affine_inverse()*bounds
		var width:float=maxf(a.width,b.width)+3.
		var length:float=a.p.distance_to(b.p)+2.
		var ribbon:=AABB(Vector3(-width,-3.,-2.),Vector3(width*2.,6.,length+4.))
		if ribbon.intersects(local): return false
	return true

static func piece(parent:Node3D,position:Vector3,size:Vector3,material:Material)->void:
	var mesh:=MeshInstance3D.new()
	var shape:=BoxMesh.new()
	shape.size=size
	mesh.mesh=shape
	mesh.position=position
	mesh.material_override=material
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
