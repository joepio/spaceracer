extends SceneTree
const Ship=preload("res://src/ship.gd")
const Race=preload("res://src/race.gd")
const Vfx=preload("res://src/weapon_vfx.gd")
func _initialize()->void: root.unfocusable=true;call_deferred("run")
func capture(name_value:String)->void:
	for i in range(15): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/red-racer-"+name_value+".png")
func run()->void:
	root.size=Vector2i(1440,1000)
	var scene:=Node3D.new();root.add_child(scene)
	var world:=WorldEnvironment.new();var env:=Environment.new();world.environment=env;scene.add_child(world)
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("222830")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("b2c1ce");env.ambient_light_energy=.28
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.glow_enabled=true;env.glow_intensity=.3
	env.ssao_enabled=true
	var sun:=DirectionalLight3D.new();scene.add_child(sun);sun.rotation_degrees=Vector3(-48,-35,0);sun.light_energy=1.6;sun.shadow_enabled=true
	var fill:=DirectionalLight3D.new();scene.add_child(fill);fill.rotation_degrees=Vector3(-20,135,0);fill.light_energy=.5;fill.light_color=Color("a0c8ff")
	var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(200,200)
	var floor_mat:=StandardMaterial3D.new();floor_mat.albedo_color=Color("242a31");floor_mat.roughness=.8;floor_mesh.material_override=floor_mat;floor_mesh.position.y=-.64;scene.add_child(floor_mesh)
	var ship:=Ship.build(Color("bf3334"));scene.add_child(ship)
	var race:=Race.new([{"slot":0}],31);var p:Dictionary=race.racers[0]
	p.airborne=true;p.air_frame=Basis.IDENTITY;p.air_position=Vector3.ZERO;p.air_time=.5;p.engine_power=.12;p.startup=1.
	Ship.animate_effects(ship,p,4.,0.)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.fov=39.
	for entry in [["front",Vector3(8.5,6.8,10.5)],["rear",Vector3(8,6,-11.5)],["top",Vector3(.01,17,.01)]]:
		camera.position=entry[1];camera.look_at(Vector3(0,.55,.3));await capture(entry[0])
	p.input_pitch=-.8;p.input_strafe=.8;p.input_steer=.85;p.brake_vfx=.85;p.input_brake=.85
	Ship.animate_controls(ship,p);camera.position=Vector3(8,6,-11.5);camera.look_at(Vector3(0,.7,0));await capture("controls")
	p.input_pitch=0.;p.input_strafe=0.;p.input_steer=0.;p.brake_vfx=0.;p.input_brake=0.;Ship.animate_controls(ship,p)
	var vfx:=Vfx.new();scene.add_child(vfx);vfx.configure(race)
	camera.position=Vector3(8.5,6.8,10.5);camera.look_at(Vector3(0,.65,.3))
	for kind in ["missile","drone","railgun","bomb","emp","warp"]:
		p.weapon=kind;vfx.update();await capture(kind)
	p.weapon="drone";vfx.update()
	camera.position=Vector3(8,6,-11.5);camera.look_at(Vector3(0,.7,0));await capture("sentry-rear")
	camera.position=Vector3(2.7,3.9,-7.);camera.look_at(Vector3(0,1.95,-1.8));await capture("sentry-detail")
	p.drone_time=2.;p.drone_target=-1;race.vfx_clock=2.13;vfx.update();await capture("sentry-active")
	p.drone_time=0.;vfx.update()
	for entry in [["sentry-left",Vector3(-4,3.4,-4.5)],["sentry-front",Vector3(3.8,3.7,3.5)]]:
		camera.position=entry[1];camera.look_at(Vector3(0,2.,-.8));await capture(entry[0])
	print("RACER_DESIGN_RENDER complete")
	scene.queue_free();await process_frame;quit()
