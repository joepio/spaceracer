extends Node3D
## One bounded explosion per craft, driven by the pausable race clock.
var serial:=-1
var started:=0.
var fire:MultiMesh
var debris:MultiMesh
var smoke:MultiMesh
var flash:OmniLight3D

func batch(count:int,mesh:Mesh,glowing:bool)->MultiMesh:
	var data:=MultiMesh.new()
	data.transform_format=MultiMesh.TRANSFORM_3D;data.use_colors=true
	data.mesh=mesh;data.instance_count=count
	var renderer:=MultiMeshInstance3D.new()
	renderer.multimesh=data;renderer.layers=2
	renderer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED if glowing else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.roughness=.95
	if glowing:
		material.emission_enabled=true;material.emission=Color("ff8525");material.emission_energy_multiplier=2.
	renderer.material_override=material
	if glowing:
		var fire_material:=ShaderMaterial.new()
		fire_material.shader=load("res://src/explosion.gdshader")
		renderer.material_override=fire_material
	add_child(renderer)
	return data

func _ready()->void:
	var sphere:=SphereMesh.new();sphere.radial_segments=12;sphere.rings=6
	fire=batch(14,sphere,true)
	debris=batch(22,BoxMesh.new(),false)
	smoke=batch(12,sphere,false)
	flash=OmniLight3D.new();flash.light_color=Color("ffb35d");flash.omni_range=65.;flash.shadow_enabled=false
	add_child(flash)
	visible=false

func update(p:Dictionary,time:float)->void:
	if p.crash_id!=serial:
		serial=p.crash_id;started=time
		position=p.air_position
	visible=p.crashed and serial>0
	if not visible: return
	var age:=maxf(0.,time-started)
	flash.light_energy=14.*pow(maxf(0.,1.-age/.65),2.)
	for i in range(14):
		var direction:=Vector3(sin(i*2.4),cos(i*3.1)*.6,sin(i*4.7)).normalized()
		var scale:=maxf(.01,(2.8+i%4)*(.3+minf(age,.4)*3.))
		fire.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale),direction*minf(age,1.2)*(9.+i*.65)))
		fire.set_instance_color(i,Color(1.,.4+float(i%3)*.2,.08,maxf(0.,1.-age/(.55+i*.045))))
	for i in range(22):
		var velocity:=Vector3(sin(i*4.1)*25.,9.+i%8*2.,cos(i*2.4)*25.)
		var at:=velocity*age+Vector3.DOWN*age*age*10.
		var basis:=Basis(Vector3(1.,.7,.3).normalized(),age*(i%5+2)).scaled(Vector3(.3,.25,1.+i%3*.5))
		debris.set_instance_transform(i,Transform3D(basis,at))
		debris.set_instance_color(i,Color(.14,.12,.1,maxf(0.,1.-age/2.5)))
	for i in range(12):
		var life:=fposmod(age+i*.22,3.)
		var at:=Vector3(sin(i*2.4)*life*1.8,life*6.,cos(i*2.4)*life*1.8)
		smoke.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(2.+life*2.3)),at))
		smoke.set_instance_color(i,Color(.10,.105,.11,smoothstep(0.,.3,life)*(1.-life/3.)*.5))
