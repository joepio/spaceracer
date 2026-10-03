extends RefCounted
## Instanced static architecture plus a small number of animated landmarks.
const Track=preload("res://src/track.gd")
const Animals=preload("res://src/animals.gd")
var animals:RefCounted
var rings:Array[Node3D]=[]
var traffic:MultiMesh
var water:ShaderMaterial
var accent:Color
var secondary:Color

static func mat(color:Color,emission:float=0.0)->StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=.45
	m.metallic=.4
	if emission>0:
		m.emission_enabled=true
		m.emission=color
		m.emission_energy_multiplier=emission
	return m

static func instance(parent:Node3D,mesh:Mesh,material:Material,position:Vector3)->MeshInstance3D:
	var result:=MeshInstance3D.new()
	result.mesh=mesh
	result.material_override=material
	result.position=position
	parent.add_child(result)
	return result

static func batch(parent:Node3D,mesh:Mesh,material:Material,count:int)->MultiMesh:
	var data:=MultiMesh.new()
	data.transform_format=MultiMesh.TRANSFORM_3D
	data.use_colors=true
	data.mesh=mesh
	data.instance_count=count
	var renderer:=MultiMeshInstance3D.new()
	renderer.multimesh=data
	renderer.material_override=material
	renderer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(renderer)
	return data

func build(parent:Node3D,race:RefCounted)->void:
	accent=race.track.theme[3]
	secondary=race.track.theme[4]
	animals=Animals.new()
	animals.build(parent,race.track)
	var rng:=RandomNumberGenerator.new()
	rng.seed=race.track.seed_value+70
	var architecture:=ShaderMaterial.new()
	architecture.shader=load("res://src/city.gdshader")
	architecture.set_shader_parameter("accent",Vector3(accent.r,accent.g,accent.b))
	architecture.set_shader_parameter("secondary",Vector3(secondary.r,secondary.g,secondary.b))
	var buildings:=batch(parent,BoxMesh.new(),architecture,260)
	var roofs:=batch(parent,BoxMesh.new(),mat(secondary,.6),260)
	for i in range(260):
		var a:=rng.randf()*TAU
		var radius:=rng.randf_range(100,740) if i<190 else rng.randf_range(1700,2600)
		var height:=rng.randf_range(80,430)
		var size:=Vector3(rng.randf_range(22,65),height,rng.randf_range(22,65))
		var position:=Vector3(sin(a)*radius,height*.5-180,cos(a)*radius)
		# Preserve space around the wildlife islands for clear silhouettes.
		for landmark in animals.placements:
			if Vector2(position.x-landmark.x,position.z-landmark.z).length()<520:
				position.x*=.38
				position.z*=.38
		buildings.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(size),position))
		buildings.set_instance_color(i,Color(rng.randf(),rng.randf(),rng.randf()))
		roofs.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(size.x*1.05,1.8,size.z*1.05)),position+Vector3.UP*(height*.5-7)))
	# Crystalline mesas, with an illuminated upper stratum and dark rock below.
	var crystal:=CylinderMesh.new()
	crystal.top_radius=.35
	crystal.bottom_radius=1
	crystal.height=1
	crystal.radial_segments=6
	var stone:=mat(Color("172944"))
	stone.metallic=0
	stone.roughness=.92
	var rocks:=batch(parent,crystal,stone,76)
	var strata:=batch(parent,crystal,mat(secondary.darkened(.3),.15),76)
	for i in range(76):
		var a:=float(i)/76*TAU
		var r:=rng.randf_range(2300,3500)
		var height:=rng.randf_range(230,950)
		var size:=Vector3(rng.randf_range(120,310),height,rng.randf_range(120,310))
		var position:=Vector3(sin(a)*r,height*.5-240,cos(a)*r)
		var rotation:=Basis(Vector3.UP,rng.randf()*TAU)
		rocks.set_instance_transform(i,Transform3D(rotation.scaled(size),position))
		strata.set_instance_transform(i,Transform3D(rotation.scaled(Vector3(size.x*.65,8,size.z*.65)),position+Vector3.UP*height*.23))
	# Water occupies the far-below layer, giving height and silhouettes context.
	var plane:=PlaneMesh.new()
	plane.size=Vector2(18000,18000)
	water=ShaderMaterial.new()
	water.shader=load("res://src/water.gdshader")
	water.set_shader_parameter("accent",Vector3(accent.r,accent.g,accent.b))
	instance(parent,plane,water,Vector3(0,-210,0))
	# Huge ringed planet: shaded bands and a thin disc rather than a blank sphere.
	var planet_material:=ShaderMaterial.new()
	planet_material.shader=load("res://src/planet.gdshader")
	planet_material.set_shader_parameter("tint",Vector3(secondary.r,secondary.g,secondary.b))
	var sphere:=SphereMesh.new()
	sphere.radius=650
	sphere.height=1300
	sphere.radial_segments=64
	sphere.rings=32
	var planet:=instance(parent,sphere,planet_material,Vector3(-2400,1200,-2800))
	planet.rotation.z=-.32
	var ring_shape:=TorusMesh.new()
	ring_shape.inner_radius=820
	ring_shape.outer_radius=1060
	ring_shape.rings=96
	ring_shape.ring_segments=6
	var ring:=instance(planet,ring_shape,mat(secondary.lightened(.25),.15),Vector3.ZERO)
	ring.scale.y=.025
	# An orbital reactor and smaller track-side turbines give the scene motion.
	var hub:=Node3D.new()
	parent.add_child(hub)
	hub.position=Vector3(0,420,0)
	for i in range(3):
		var shape:=TorusMesh.new()
		shape.inner_radius=190+i*35
		shape.outer_radius=194+i*35
		shape.rings=64
		shape.ring_segments=6
		var hoop:=instance(hub,shape,mat(accent if i%2==0 else secondary,.6),Vector3.ZERO)
		hoop.rotation=Vector3(.4+i*.5,0,.7+i*.3)
		rings.append(hoop)
	var core:=SphereMesh.new()
	core.radius=65
	core.height=130
	instance(hub,core,mat(accent,.9),Vector3.ZERO)
	# Sparse holographic pylons along the road. All instanced in a single draw.
	var pylons:=batch(parent,BoxMesh.new(),mat(accent,.5),ceili(race.track.nodes.size()/22.0))
	var index:=0
	for i in range(0,race.track.nodes.size(),22):
		var n:Dictionary=race.track.nodes[i]
		pylons.set_instance_transform(index,Transform3D(Track.basis_at(n).scaled(Vector3(.6,8,.6)),Track.point(n,n.width+4,4)))
		index+=1
	# Ambient traffic stays away from the racing surface; it is scenery, not a hazard.
	traffic=batch(parent,BoxMesh.new(),mat(secondary,.8),24)
	animate(0)

func animate(time:float)->void:
	animals.animate(time)
	for i in range(rings.size()):
		rings[i].rotation=Vector3(.4+i*.5+time*.035, time*(.10 if i%2==0 else -.08), .7+i*.3)
	water.set_shader_parameter("race_time",time)
	for i in range(24):
		var a:=i*TAU/24+time*(.035 if i%2==0 else -.026)
		var radius:=450+i%3*100
		var position:=Vector3(sin(a)*radius,60+i%4*38,cos(a)*radius)
		traffic.set_instance_transform(i,Transform3D(Basis(Vector3.UP,a).scaled(Vector3(3,2,30)),position))
