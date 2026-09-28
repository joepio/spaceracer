extends RefCounted
## Energy-driven paint and one bounded smoke draw per critically damaged craft.
const PARTICLES:=12
const SMOKE_ENERGY:=22.

static func build(ship:Node3D)->void:
	var smoke:=MultiMeshInstance3D.new();smoke.name="DamageSmoke"
	var mesh:=MultiMesh.new();mesh.transform_format=MultiMesh.TRANSFORM_3D;mesh.use_colors=true
	mesh.mesh=QuadMesh.new();mesh.instance_count=PARTICLES
	smoke.multimesh=mesh;smoke.visible=false
	smoke.custom_aabb=AABB(Vector3(-7.,-2.,-19.),Vector3(14.,12.,24.))
	smoke.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new();material.shader=load("res://src/damage_smoke.gdshader")
	material.set_shader_parameter("wear_mask",load("res://assets/paint-wear.png"))
	smoke.material_override=material;ship.add_child(smoke)
	ship.set_meta("damage_smoke",smoke)
	ship.set_meta("visual_damage",-1.)

static func update(ship:Node3D,p:Dictionary,time:float)->void:
	var damage:=1.-clampf(p.energy/100.,0.,1.)
	if not is_equal_approx(damage,float(ship.get_meta("visual_damage",-1.))):
		for material in ship.get_meta("damage_materials"): material.set_shader_parameter("damage",damage)
		ship.set_meta("visual_damage",damage)
	var smoke:MultiMeshInstance3D=ship.get_meta("damage_smoke")
	var amount:=smoothstep(0.,SMOKE_ENERGY,SMOKE_ENERGY-p.energy)
	smoke.visible=amount>.001 and not p.crashed and p.recovery<=0.
	if not smoke.visible: return
	# Short, overlapping wisps from hot engine panels, not another exhaust plume.
	# Race time makes the effect freeze with pause. Only twelve quads per craft.
	var mesh:MultiMesh=smoke.multimesh
	for i in range(PARTICLES):
		var side:=-1. if i%2==0 else 1.
		var age:=fposmod(time*.85+float(i/2)/6.+side*.137,1.)
		var envelope:=smoothstep(0.,.12,age)*(1.-smoothstep(.5,1.,age))
		var diameter:=lerpf(1.2,4.4,age)
		var drift:=sin(i*7.19+age*3.)*age*.8
		var at:=Vector3(side*2.45+drift,.9+age*(2.5 if p.speed>40. else 5.),-1.9-age*minf(12.,p.speed*.07))
		mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*diameter),at))
		mesh.set_instance_color(i,Color(.18,.17,.16,envelope*amount*.42))
