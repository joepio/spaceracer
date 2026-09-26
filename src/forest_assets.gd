extends RefCounted
## Authored CC-BY trees from GamesNotDeveloped/godot-forest-demo.
## Keep imported meshes (including Godot's generated LODs) shared by all instances.
const PATHS:=["res://assets/forest/authored/pine-tree-1/scene.gltf","res://assets/forest/authored/birch-tree-1/scene.gltf"]
static var cache:Array[Dictionary]=[]

static func collect(node:Node,transform:Transform3D,parts:Array)->void:
	if node is Node3D: transform=transform*node.transform
	if node is MeshInstance3D:
		parts.append({"mesh":node.mesh,"transform":transform})
	for child in node.get_children(): collect(child,transform,parts)

static func model(variant:int)->Dictionary:
	if cache.is_empty():
		for path in PATHS: cache.append(import_model(path))
	return cache[variant]

static func import_model(path:String)->Dictionary:
	var scene:Node=load(path).instantiate()
	var parts:Array=[]
	collect(scene,Transform3D.IDENTITY,parts)
	scene.free()
	var envelope:AABB=parts[0].transform*parts[0].mesh.get_aabb()
	for part in parts: envelope=envelope.merge(part.transform*part.mesh.get_aabb())
	var scale:=1./envelope.size.y
	var normalization:=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale),Vector3(0.,-envelope.position.y*scale,0.))
	var bounds:Array[AABB]=[]
	var solids:Array[AABB]=[]
	for part in parts:
		part.transform=normalization*part.transform
		bounds.append(part.transform*part.mesh.get_aabb())
		# Each imported component has one material; alpha-scissor foliage writes
		# depth and shadows without transparent sorting or an extra blend pass.
		var material:StandardMaterial3D=part.mesh.surface_get_material(0).duplicate()
		var leaves:=material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED
		material.vertex_color_use_as_albedo=true
		material.metallic=0.;material.metallic_specular=.12
		material.roughness=.95
		material.backlight_enabled=false
		if leaves:
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold=.24 if "pine-tree" in path else .4
			if "pine-tree" in path: material.albedo_color=Color(.55,.72,.48)
			material.cull_mode=BaseMaterial3D.CULL_DISABLED
		part.material=material
		part.leaves=leaves
		if not leaves:
			# Tight vertical sections around the lower solid trunk. Canopy cards
			# are intentionally not solid; no giant collision wall around the crown.
			var vertices:PackedVector3Array=part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for band in range(10):
				var points:Array[Vector3]=[]
				for vertex in vertices:
					var p:Vector3=part.transform*vertex
					if p.y>=band*.05 and p.y<=(band+1)*.05: points.append(p)
				if points.is_empty(): continue
				var trunk:=AABB(points[0],Vector3.ZERO)
				for p in points: trunk=trunk.expand(p)
				trunk.position.y=band*.05;trunk.size.y=.05
				solids.append(trunk.grow(.002))
	return {"parts":parts,"bounds":bounds,"solids":solids}
