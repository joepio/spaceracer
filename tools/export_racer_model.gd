extends SceneTree
## Portable editable GLB: preserves control pivots; game-only optical VFX stay in Godot.
const Ship=preload("res://src/ship.gd")
func convert_materials(node:Node3D)->void:
	if node is MeshInstance3D and node.material_override is ShaderMaterial:
		var original:ShaderMaterial=node.material_override
		var mat:=StandardMaterial3D.new();var tint:Variant=original.get_shader_parameter("tint")
		mat.albedo_color=tint if tint is Color else Color("bf3334")
		mat.metallic=.32;mat.roughness=.31;mat.clearcoat_enabled=true;mat.clearcoat=.55
		node.material_override=mat
	for child in node.get_children():
		if child is Node3D: convert_materials(child)
func _initialize()->void: call_deferred("run")
func run()->void:
	var ship:=Ship.build(Color("bf3334"));ship.name="IonRush_RedRacer";root.add_child(ship)
	for child in ship.get_children():
		if child.name in ["DamageSmoke","RebuildLight"] or child.name.begins_with("Engine") or child.name.begins_with("Exhaust") or child.name.begins_with("Boost") or child.name.begins_with("Reverse"):
			ship.remove_child(child);child.free()
	convert_materials(ship)
	var document:=GLTFDocument.new();var state:=GLTFState.new()
	var error:=document.append_from_scene(ship,state)
	if error==OK: error=document.write_to_filesystem(state,"res://docs/vehicle-concepts/red-racer-v1.glb")
	if error==OK:
		var verify:=GLTFState.new();error=document.append_from_file("res://docs/vehicle-concepts/red-racer-v1.glb",verify)
		if error==OK:
			var restored:=document.generate_scene(verify)
			for pivot in ["WingControlL","WingControlR","RudderL","RudderR","WeaponSocket"]:
				if restored.find_child(pivot,true,false)==null: error=ERR_INVALID_DATA
			restored.free()
	print("RACER_GLB_EXPORT error=",error)
	ship.queue_free();await process_frame;quit(0 if error==OK else 1)
