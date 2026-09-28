extends SceneTree
const Ship=preload("res://src/ship.gd")
const Race=preload("res://src/race.gd")
func _initialize()->void: root.unfocusable=true;call_deferred("run")
func run()->void:
	root.size=Vector2i(1440,900)
	var scene:=Node3D.new();root.add_child(scene)
	var world:=WorldEnvironment.new();var env:=Environment.new();world.environment=env;scene.add_child(world)
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("222830")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("b2c1ce");env.ambient_light_energy=.28
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.ssao_enabled=true
	var sun:=DirectionalLight3D.new();scene.add_child(sun);sun.rotation_degrees=Vector3(-48,-35,0);sun.light_energy=1.6;sun.shadow_enabled=true
	var fill:=DirectionalLight3D.new();scene.add_child(fill);fill.rotation_degrees=Vector3(-20,135,0);fill.light_energy=.5;fill.light_color=Color("a0c8ff")
	var ship:=Ship.build(Color("bf3334"));scene.add_child(ship)
	var race:=Race.new([{"slot":0}],31);var p:Dictionary=race.racers[0]
	p.airborne=true;p.air_frame=Basis.IDENTITY;p.air_position=Vector3.ZERO;p.air_time=.5;p.engine_power=.08;p.startup=1.;p.speed=180.
	Ship.animate_effects(ship,p,4.,0.)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.fov=39.
	camera.position=Vector3(8.5,6.8,10.5);camera.look_at(Vector3(0,.55,.3))
	for energy in [100.,55.,12.]:
		p.energy=energy;Ship.Wear.update(ship,p,4.)
		for i in range(20): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/vehicle-wear-%d.png"%energy)
	# Rear view is what racers actually see most of the time.
	camera.position=Vector3(6,5,-12);camera.look_at(Vector3(0,.7,-.6))
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/vehicle-wear-rear.png")
	print("VEHICLE_WEAR_RENDER complete")
	scene.queue_free();await process_frame;quit()
