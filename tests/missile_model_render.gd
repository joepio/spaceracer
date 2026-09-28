extends SceneTree
const Vfx=preload("res://src/weapon_vfx.gd")
func _initialize()->void:
	root.unfocusable=true;call_deferred("run")
func run()->void:
	var scene:=Node3D.new();root.add_child(scene)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("17212e")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("91abc7");environment.environment.ambient_light_energy=.65
	scene.add_child(environment)
	var light:=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.8
	var builder:=Vfx.new();scene.add_child(builder)
	builder.steel=Vfx.material(Color("283b50"));builder.flame=Vfx.material(Color("ffac42"),3.)
	var missile:=Node3D.new();scene.add_child(missile);builder.missile_hull(missile)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.fov=35.
	camera.position=Vector3(12,7,13);camera.look_at(Vector3(0,0,0))
	for frame in range(15): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/missile-model.png")
	scene.queue_free();await process_frame;quit()
