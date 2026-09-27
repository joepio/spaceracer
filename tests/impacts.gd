extends SceneTree
const Race=preload("res://src/race.gd")
const Impact=preload("res://src/impact_vfx.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void:
	root.unfocusable=true;call_deferred("run")
func run()->void:
	var race:=Race.new([{"slot":0},{"slot":1}],31)
	race.countdown=0.;race.clock=5.
	var p:Dictionary=race.racers[0];p.distance=100.;p.speed=200.
	var frame:=race.Weapons.pose(race,p)
	race.weapons.damage(race,p,4.,1.,frame*Vector3(-20,0,0))
	check((frame.affine_inverse()*p.impact_frame.origin).x< -3.,"Hit burst starts on the struck side")
	check(p.impact_velocity.length()>190.,"Debris inherits craft momentum")
	var id:int=p.impact_id
	p.weapon_guard=1.;race.weapons.damage(race,p,4.,1.)
	check(p.impact_id==id,"Blocked damage does not generate hit debris")
	p.weapon_guard=0.;race.weapons.damage(race,p,14.,1.,frame*Vector3(20,0,0))
	check(p.impact_id==id+1 and p.impact_age==0.,"A fresh hit restarts the short burst")
	var visual:=Impact.new();root.add_child(visual)
	for age in [.0,.07,.18,.4,.56]:
		p.impact_age=age;visual.show_hit(p)
		check(visual.visible==(age<Impact.LIFE),"Hit visual expires in half a second")
		if visual.visible:
			check(not visual.blast.heat.visible,"Hit does not create a refractive shield shell")
			check(visual.blast.flash.visible==(age<.09),"Impact light is brief")
			for i in range(visual.debris.instance_count): check(visual.debris.get_instance_transform(i).origin.is_finite(),"Debris motion stays finite")
	visual.queue_free();await process_frame
	if "--render" in OS.get_cmdline_user_args(): await render_scene()
	print("IMPACT_TESTS %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func render_scene()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game)
	game.human_count=1;game.next_seed=31;game.start_local()
	game.set_process(false);game.set_physics_process(false)
	game.race.countdown=0.;game.race.clock=12.
	var p:Dictionary=game.race.racers[0];p.distance=150.;p.startup=1.;p.engine_power=.15;p.speed=0.
	var frame:=Race.Weapons.pose(game.race,p)
	var camera:Camera3D=game.views[0].camera
	camera.position=frame*Vector3(10,7,-13);camera.look_at(frame*Vector3(0,1,0),frame.basis.y);camera.fov=55.
	game.race.weapons.damage(game.race,p,14.,1.,frame*Vector3(20,2,-4))
	for age in [.04,.15,.4,.56]:
		p.impact_age=age;game.world.update_ships();game.views[0].hud.queue_redraw()
		for capture_tick in range(15): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/hit-%.2f.png"%age)
	game.queue_free();await process_frame
