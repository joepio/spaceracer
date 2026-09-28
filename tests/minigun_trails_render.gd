extends SceneTree
func _initialize()->void: root.unfocusable=true;call_deferred("run")
func capture(name_value:String)->void:
	for tick in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/"+name_value+".png")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.human_count=1;game.biome="city";game.next_seed=31;game.start_local()
	game.set_process(false);game.set_physics_process(false);game.running=true;game.in_menu=false
	var race:RefCounted=game.race;race.countdown=0.;race.clock=20.
	var p:Dictionary=race.racers[0];p.distance=1100.;p.x=0.;p.speed=350.;p.boost=1.;p.thrust=1.;p.engine_power=1.;p.startup=1.
	var showcase:=1100.
	for n in race.track.nodes:
		if absf(n.curve)>.008 and not n.air_gap and not n.loop:
			showcase=race.track.nodes.find(n)*race.track.step-60.;break
	for tick in range(30):
		p.distance=showcase+tick*350./60.;race.vfx_clock=20.+tick/60.;game.world.update_ships()
	var frame:Transform3D=race.Weapons.pose(race,p)
	var camera:Camera3D=game.views[0].camera
	camera.position=frame*Vector3(27.,17.,-40.);camera.look_at(frame*Vector3(0,0,-18.),frame.basis.y);camera.fov=65.
	game.views[0].hud.visible=false
	await capture("boost-analog-trails")
	p.boost=0.;race.vfx_clock+=1.;p.weapon="drone";race.weapons.activate(race,0)
	race.racers[1].distance=p.distance+60.;p.drone_cooldown=0.
	race.weapons.begin_step(race,.001,[{},{},{},{},{},{}]);race.weapons.end_step(race,.001);game.world.update_ships()
	frame=race.Weapons.pose(race,p)
	camera.position=frame*Vector3(8.,5.,-7.);camera.look_at(frame*Vector3(0,1.6,.5),frame.basis.y);camera.fov=55.
	await capture("minigun-muzzle-flash")
	game.world.update_ships();await capture("minigun-between-shots")
	game.queue_free();await process_frame;quit()
