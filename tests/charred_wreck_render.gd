extends SceneTree
const Race=preload("res://src/race.gd")
const Ship=preload("res://src/ship.gd")
const Crash=preload("res://src/crash_vfx.gd")
func _initialize()->void: root.unfocusable=true;call_deferred("run")
func capture(name_value:String)->void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/"+name_value+".png")
func run()->void:
	var scene:=Node3D.new();root.add_child(scene)
	var environment:=WorldEnvironment.new();var env:=Environment.new();environment.environment=env;scene.add_child(environment)
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("182b36")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("cadbe2");env.ambient_light_energy=.7
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.glow_enabled=true;env.glow_intensity=.5;env.glow_hdr_threshold=1.5
	var sun:=DirectionalLight3D.new();scene.add_child(sun);sun.rotation_degrees=Vector3(-55,-25,0);sun.light_energy=1.8
	var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(160,160);floor_mesh.mesh=plane
	var floor_mat:=StandardMaterial3D.new();floor_mat.albedo_color=Color("36414a");floor_mat.roughness=.8;floor_mesh.material_override=floor_mat;scene.add_child(floor_mesh)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.position=Vector3(8,15,22);camera.look_at(Vector3(0,1,1));camera.fov=58.
	var race:=Race.new([{"slot":0},{"slot":1}],31)
	var effects:Array=[]
	for i in range(2):
		var p:Dictionary=race.racers[i];var color:=Color("ff315e") if i==0 else Color("31efd4")
		var ship:=Ship.build(color);scene.add_child(ship);ship.position=Vector3(-8 if i==0 else 8,1,0)
		var effect:=Crash.new();scene.add_child(effect);effect.configure(ship);effects.append(effect)
		p.air_position=ship.position;p.air_frame=Basis.IDENTITY;p.ground_velocity=Vector3.ZERO
		Race.Flight.crash(p);effect.update(p,0.);ship.visible=false
		print("WRECK_COLOR original=",effect.material_sources[0].original.get_shader_parameter("tint")," type=",typeof(effect.material_sources[0].original.get_shader_parameter("tint"))," burnt=",effect.material_sources[0].burnt.get_shader_parameter("tint"))
		# Spread the actual fragment meshes for a material/flame inspection.
		for j in range(p.wreck.pieces.size()):
			var piece:Dictionary=p.wreck.pieces[j]
			piece.frame.origin+=Vector3(sin(j*2.4)*1.7,j%3*.2,cos(j*2.4)*1.7)
			piece.frame.basis=Basis(Vector3(1,.4,.7).normalized(),j*.25)
	for age in [.65,1.2]:
		for i in range(2): effects[i].update(race.racers[i],age)
		# Keep the blast hidden only for the material closeup, so its smoke does
		# not obscure the colors and char patches under inspection.
		for effect in effects: effect.blast.visible=false
		await capture("charred-parts-%.2f"%age)
	for i in range(2): effects[i].update(race.racers[i],.45)
	await capture("charred-wreck-explosion")
	scene.queue_free();await process_frame;quit()
