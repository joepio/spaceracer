extends Node3D
## Draws every distinct mesh/material pair in the world a few times, off-screen,
## while the race is still loading. Godot compiles a shader and its pipelines
## the first time something using it is drawn, so pooled effects that start
## hidden (missiles, blasts, wrecks, rail beams) would otherwise stall the frame
## in which they first appear. Copies share the original meshes and materials,
## render through a tiny viewport far below the map and free themselves.
const SPOT:=Vector3(0.,-20000.,0.)
const FRAMES:=5
var viewport:SubViewport
var frames_left:=FRAMES
var proxies:=0

## Adds the warmup under `root` and starts drawing. `template` is a race view;
## the warm viewport copies its AA, shadow atlas and compositor so the same
## pipeline variants (MSAA, motion vectors) get built.
static func run(root:Node3D,template:SubViewport,template_camera:Camera3D)->Node3D:
	var warmup:=new()
	warmup.name="RenderWarmup"
	warmup.process_mode=Node.PROCESS_MODE_ALWAYS
	warmup.collect(root,{})
	root.add_child(warmup)
	warmup.build_viewport(template,template_camera)
	return warmup

static func material_key(material:Material)->String:
	if material==null: return "-"
	var key:="m%d"%material.get_instance_id()
	if material is ShaderMaterial:
		# Per-instance ShaderMaterials of one shader share the compiled shader.
		key="s%d"%(material.shader.get_instance_id() if material.shader!=null else 0)
	return key+"/"+material_key(material.next_pass)

static func surface_format(mesh:Mesh,surface:int)->String:
	if mesh is ArrayMesh: return "%d:%d"%[mesh.surface_get_format(surface),mesh.surface_get_primitive_type(surface)]
	return mesh.get_class()

func collect(node:Node,seen:Dictionary)->void:
	if node is GeometryInstance3D: consider(node,seen)
	for child in node.get_children(): collect(child,seen)

func consider(source:GeometryInstance3D,seen:Dictionary)->void:
	var common:="%d|%s|%s"%[source.cast_shadow,source.transparency>0.,material_key(source.material_overlay)]
	var keys:PackedStringArray=[]
	var copy:GeometryInstance3D
	if source is MeshInstance3D:
		var mesh:Mesh=source.mesh
		if mesh==null: return
		for i in range(mesh.get_surface_count()):
			keys.append("mesh|%s|%s|%s"%[common,surface_format(mesh,i),material_key(source.get_active_material(i))])
		if not unseen(keys,seen): return
		var mesh_copy:=MeshInstance3D.new();mesh_copy.mesh=mesh
		for i in range(mesh.get_surface_count()): mesh_copy.set_surface_override_material(i,source.get_surface_override_material(i))
		copy=mesh_copy
	elif source is MultiMeshInstance3D:
		var batch:MultiMesh=source.multimesh
		if batch==null or batch.mesh==null: return
		var layout:="%d%s%s"%[batch.transform_format,batch.use_colors,batch.use_custom_data]
		for i in range(batch.mesh.get_surface_count()):
			var active:Material=source.material_override if source.material_override!=null else batch.mesh.surface_get_material(i)
			keys.append("multi|%s|%s|%s|%s"%[common,layout,surface_format(batch.mesh,i),material_key(active)])
		if not unseen(keys,seen): return
		var single:=MultiMesh.new()
		single.transform_format=batch.transform_format
		single.use_colors=batch.use_colors;single.use_custom_data=batch.use_custom_data
		single.mesh=batch.mesh;single.instance_count=1
		single.set_instance_transform(0,Transform3D.IDENTITY)
		if single.use_colors: single.set_instance_color(0,Color.WHITE)
		if single.use_custom_data: single.set_instance_custom_data(0,Color(.5,.5,.5,.5))
		var batch_copy:=MultiMeshInstance3D.new();batch_copy.multimesh=single
		copy=batch_copy
	else:
		keys.append("%s|%s|%s"%[source.get_class(),common,material_key(source.material_override)])
		if not unseen(keys,seen): return
		copy=source.duplicate(0) as GeometryInstance3D
		if copy==null: return
		for child in copy.get_children(): copy.remove_child(child);child.free()
	copy.material_override=source.material_override
	copy.material_overlay=source.material_overlay
	copy.cast_shadow=source.cast_shadow
	copy.transparency=source.transparency
	copy.layers=source.layers
	copy.visible=true
	# Never culled: vertex shaders may move geometry far from its mesh bounds.
	copy.custom_aabb=AABB(Vector3.ONE*-1000.,Vector3.ONE*2000.)
	copy.position=SPOT+Vector3(0.,0.,-12.)
	add_child(copy)
	proxies+=1

func unseen(keys:PackedStringArray,seen:Dictionary)->bool:
	var fresh:=false
	for key in keys:
		if not seen.has(key): seen[key]=true;fresh=true
	return fresh

func build_viewport(template:SubViewport,template_camera:Camera3D)->void:
	viewport=SubViewport.new()
	viewport.size=Vector2i(256,144)
	viewport.world_3d=template.world_3d
	viewport.msaa_3d=template.msaa_3d
	viewport.screen_space_aa=template.screen_space_aa
	viewport.use_taa=template.use_taa
	viewport.positional_shadow_atlas_size=template.positional_shadow_atlas_size
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera:=Camera3D.new()
	camera.near=template_camera.near;camera.far=template_camera.far
	camera.environment=template_camera.environment
	camera.attributes=template_camera.attributes
	camera.compositor=template_camera.compositor
	camera.cull_mask=0xFFFFF
	viewport.add_child(camera)
	camera.global_transform=Transform3D(Basis.IDENTITY,SPOT)
	camera.current=true

func _process(_dt:float)->void:
	frames_left-=1
	if frames_left<=0: queue_free()
