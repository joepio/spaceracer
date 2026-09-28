extends RefCounted
## Temporary additive scan on existing hull geometry, with one short local light.
const DURATION:=.7
static func collect(node:Node,meshes:Array[MeshInstance3D])->void:
	if node is MeshInstance3D: meshes.append(node)
	for child in node.get_children(): collect(child,meshes)

static func build(ship:Node3D)->void:
	var meshes:Array[MeshInstance3D]=[];collect(ship,meshes)
	ship.set_meta("rebuild_meshes",meshes)
	var material:=ShaderMaterial.new();material.shader=load("res://src/respawn_scan.gdshader")
	ship.set_meta("rebuild_material",material);ship.set_meta("rebuild_active",false)
	var light:=OmniLight3D.new();light.name="RebuildLight";light.position=Vector3(0,1.1,0)
	light.light_color=Color("75eaff");light.omni_range=15.;light.shadow_enabled=false;light.visible=false
	ship.add_child(light);ship.set_meta("rebuild_light",light)

static func update(ship:Node3D,p:Dictionary)->void:
	var left:float=p.get("rebuild_time",0.)
	var active:bool=left>0. and not p.crashed
	var was_active:bool=ship.get_meta("rebuild_active")
	var material:ShaderMaterial=ship.get_meta("rebuild_material")
	if active!=was_active:
		for mesh in ship.get_meta("rebuild_meshes"): mesh.material_overlay=material if active else null
		ship.set_meta("rebuild_active",active)
		if not active:
			for paint in ship.get_meta("damage_materials"): paint.set_shader_parameter("rebuild_progress",1.)
	var light:OmniLight3D=ship.get_meta("rebuild_light");light.visible=active
	if not active: return
	var progress:=clampf(1.-left/DURATION,0.,1.)
	var inverse:=ship.global_transform.affine_inverse()
	material.set_shader_parameter("progress",progress)
	material.set_shader_parameter("hull_inverse",inverse)
	for paint in ship.get_meta("damage_materials"):
		paint.set_shader_parameter("rebuild_progress",minf(1.,progress*1.4))
		paint.set_shader_parameter("rebuild_inverse",inverse)
	light.light_energy=5.*sin(PI*pow(progress,.55))
