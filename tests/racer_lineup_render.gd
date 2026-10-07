extends SceneTree
## Every airframe family side by side, each in its own livery.
## godot --path . --script res://tests/racer_lineup_render.gd -- --output=/abs/dir
const Ship=preload("res://src/ship.gd")
const World=preload("res://src/world.gd")
var output:=""
func _initialize()->void: root.unfocusable=true;call_deferred("run")
func capture(name_value:String)->void:
	for i in range(15): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name_value+".png"))
	print("LINEUP_CAPTURE ",name_value)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if output.is_empty(): output=ProjectSettings.globalize_path("res://build/lineup")
	DirAccess.make_dir_recursive_absolute(output)
	var scene:=Node3D.new();root.add_child(scene)
	var world:=WorldEnvironment.new();var env:=Environment.new();world.environment=env;scene.add_child(world)
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("222830")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("b2c1ce");env.ambient_light_energy=.35
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var sun:=DirectionalLight3D.new();scene.add_child(sun);sun.rotation_degrees=Vector3(-48,-35,0);sun.light_energy=1.6;sun.shadow_enabled=true
	var fill:=DirectionalLight3D.new();scene.add_child(fill);fill.rotation_degrees=Vector3(-20,135,0);fill.light_energy=.5;fill.light_color=Color("a0c8ff")
	var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(300,300)
	var floor_mat:=StandardMaterial3D.new();floor_mat.albedo_color=Color("2a3038");floor_mat.roughness=.8;floor_mesh.material_override=floor_mat;floor_mesh.position.y=-.9;scene.add_child(floor_mesh)
	var count:int=Ship.Design.VARIANTS.size()
	for i in range(count):
		var ship:=Ship.build(World.PALETTE[(i*3+1)%World.PALETTE.size()],i);scene.add_child(ship)
		ship.position=Vector3((i-(count-1)*.5)*11.,0.,0.)
		ship.rotation.y=-.35
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.fov=40.
	root.size=Vector2i(1600,900)
	camera.position=Vector3(6,20,52);camera.look_at(Vector3(0,0,0));await capture("lineup_front")
	camera.position=Vector3(0,58,.1);camera.look_at(Vector3(0,0,0));await capture("lineup_top")
	camera.position=Vector3(-10,9,-30);camera.look_at(Vector3(0,0,0));await capture("lineup_rear")
	scene.queue_free();await process_frame;quit()
