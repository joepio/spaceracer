extends SceneTree
const Ship=preload("res://src/ship.gd")
func _initialize()->void:
	root.unfocusable=true;call_deferred("run")
func run()->void:
	var scene:=Node3D.new();root.add_child(scene)
	var world:=WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("17212e")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color("91abc7");world.environment.ambient_light_energy=.7
	scene.add_child(world)
	var light:=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.8
	var pixels:Array=[];pixels.resize(2304)
	for y in range(48):
		for x in range(48):
			if y>=12 and y<18 and x>=14 and x<=35: pixels[y*48+x]="#ff4077"
			if y>=25 and y<29 and (x in [19,20,21,28,29,30]): pixels[y*48+x]="#171b31"
			if y==34 and x>=21 and x<=28: pixels[y*48+x]="#171b31"
	var profile:={"avatar":JSON.stringify({"v":1,"w":48,"h":48,"px":pixels}),"skin_color":"#eac793","color":"#50efcc"}
	var ship:=Ship.build(Color("50efcc"));scene.add_child(ship);Ship.update_face(ship,profile)
	var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.fov=32.
	for side in [-1.,1.]:
		camera.position=Vector3(side*12.,4.,4.);camera.look_at(Vector3(0,.1,0))
		for frame in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/pilot-face-%d.png"%int(side))
	scene.queue_free();await process_frame;quit()
