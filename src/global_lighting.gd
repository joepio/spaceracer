extends RefCounted
## Static environment bounce; moving effects remain direct lights, never GI sources.
static func prepare(node:Node)->void:
	if node is GeometryInstance3D:
		var excluded:bool=(node.layers&2)!=0 or node.get_meta("gi_dynamic",false)
		var material:Material=node.material_override
		if material is ShaderMaterial and material.shader.resource_path in ["res://src/forest_water.gdshader","res://src/forest_understory.gdshader","res://src/cell_membrane.gdshader","res://src/desert_dust.gdshader","res://src/ocean_jelly.gdshader","res://src/ocean_drift.gdshader"]: excluded=true
		node.gi_mode=GeometryInstance3D.GI_MODE_DISABLED if excluded else GeometryInstance3D.GI_MODE_STATIC
	if node is Light3D: node.light_bake_mode=Light3D.BAKE_STATIC
	for child in node.get_children(): prepare(child)

static func receive_only(node:Node)->void:
	if node is GeometryInstance3D: node.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	if node is Light3D: node.light_bake_mode=Light3D.BAKE_DISABLED
	for child in node.get_children(): receive_only(child)

static func configure(env:Environment,enabled:bool,biome:String="city")->void:
	env.sdfgi_cascades=3
	env.sdfgi_min_cell_size=2.
	env.sdfgi_use_occlusion=true
	env.sdfgi_read_sky_light=biome in ["forest","desert"]
	env.sdfgi_bounce_feedback=.25
	env.sdfgi_energy=1.2
	env.sdfgi_enabled=enabled

static func surface_proxy(parent:Node3D,source:MeshInstance3D,capture_material:Material=null)->void:
	# Visible road reflections use EMISSION. A matte GI-only copy avoids feedback.
	source.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	var proxy:=MeshInstance3D.new()
	proxy.name="StaticBounceProxy"
	proxy.set_meta("road_source",source)
	proxy.mesh=source.mesh
	proxy.layers=source.layers
	proxy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	proxy.gi_mode=GeometryInstance3D.GI_MODE_STATIC
	proxy.visible=false
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(.055,.065,.08)
	material.roughness=.85
	proxy.material_override=material if capture_material==null else capture_material
	parent.add_child(proxy)
