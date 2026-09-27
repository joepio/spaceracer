extends SceneTree
const Race=preload("res://src/race.gd")
const Ship=preload("res://src/ship.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func corner(track:RefCounted,side:float)->float:
	for i in range(track.nodes.size()):
		var n:Dictionary=track.nodes[i]
		if n.curve*side>.007 and not n.loop and not n.air_gap: return i*track.step
	return -1.
func place(race:RefCounted,p:Dictionary,side:float)->void:
	p.distance=corner(race.track,side);p.x=0.;p.heading=0.;p.slip=0.;p.slide=.65
	p.speed=195.;p.startup=1.;p.ignited=true;p.engine_power=1.
func run()->void:
	var race:=Race.new([{"slot":0}],31,3,"hard")
	race.countdown=0.;race.clock=10.
	var p:Dictionary=race.racers[0]
	var ship:=Ship.build(Color.CYAN);root.add_child(ship)
	for side in [-1.,1.]:
		place(race,p,side)
		# Over-speed entry must brake; hard pilots no longer brake safe sweepers.
		p.speed=410.
		check(p.distance>=0.,"Seed contains test corner")
		var controls:Dictionary=race.bot(p)
		check(controls.strafe*side>.1 and controls.steer*side>.1,"AI coordinates actual steering and strafe in corner")
		race.step(1./120.,[controls]);Ship.animate_controls(ship,p)
		check(ship.get_node("RudderL").rotation.y*side>.1,"Rudder trailing edges deflect with the commanded yaw")
		var difference:float=ship.get_node("WingControlL").rotation.x-ship.get_node("WingControlR").rotation.x
		check(difference*side>.1,"Wing surfaces differentially respond to AI strafe")
		check(ship.get_node("Airbrake-1").rotation.x>0.,"AI braking opens airbrakes")
	# The fixed wing no longer hides the elevon at its neutral position.
	var fixed:MeshInstance3D=ship.get_node("Wing-1")
	var flap:MeshInstance3D=ship.get_node("WingControlL/Elevon")
	check(fixed.mesh.get_aabb().position.z>flap.position.z+flap.get_parent().position.z+flap.mesh.get_aabb().end.z,"Fixed wing ends before moving flap")
	place(race,p,1.);p.finished=true
	race.Victory.step(p,race.track,.1,race.clock);Ship.animate_controls(ship,p)
	check(absf(p.input_strafe)>.1 and absf(ship.get_node("RudderL").rotation.y)>.1,"Victory autopilot animates wing and rudder controls too")
	ship.queue_free();await process_frame
	if "--render" in OS.get_cmdline_user_args(): await render_scene()
	print("AI_SURFACE_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
func render_scene()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game)
	game.human_count=2;game.next_seed=31;game.difficulty="hard";game.start_local()
	game.set_process(false);game.set_physics_process(false)
	game.race.countdown=0.;game.race.clock=10.
	for i in range(game.race.racers.size()):
		place(game.race,game.race.racers[i],-1. if i%2==0 else 1.)
		if i>=2: game.race.racers[i].distance+=500.+i*100.
	for tick in range(20):
		var inputs:Array=[]
		for pilot in game.race.racers: inputs.append(game.race.bot(pilot))
		game.race.step(1./120.,inputs)
	game.world.update_ships()
	for view in game.views:
		var pilot:Dictionary=game.race.racers[view.index]
		var pose:Transform3D=game.race.Flight.pose(pilot,game.race.track.sample(pilot.distance),game.race.clock)
		view.camera.position=pose*Vector3(5.,4.,-11.)
		view.camera.look_at(pose.origin+pose.basis.y*.4,pose.basis.y);view.camera.fov=48.
		view.hud.visible=true;view.hud.queue_redraw()
	for frame in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/ai-surfaces.png")
	game.queue_free();await process_frame
