extends SceneTree
const Race=preload("res://src/race.gd")
const Vfx=preload("res://src/weapon_vfx.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void:
	root.unfocusable=true;call_deferred("run")
func run()->void:
	for airborne in [false,true]:
		for speed in [0.,200.,390.]:
			var race:=Race.new([{"slot":0},{"slot":1}],31)
			race.countdown=0.;race.clock=5.;race.racers[0].distance=2000.
			var p:Dictionary=race.racers[1];p.distance=100.;p.speed=speed;p.weapon="missile"
			p.airborne=airborne;p.air_frame=Basis(Vector3.FORWARD,.5);p.air_position=Vector3(0,200,0);p.air_velocity=p.air_frame.z*speed
			var frame:=Race.Weapons.pose(race,p)
			race.weapons.activate(race,1)
			var m:Dictionary=race.weapons.missiles[0]
			check(m.position.distance_to(frame*Race.Weapons.MISSILE_MOUNT)<.001,"Missile spawns exactly on its mounted rail")
			check(absf(m.velocity.length()-speed)<.001,"Launch inherits vehicle speed")
			var last_speed:float=m.launch_speed
			for tick in range(130):
				var previous:Vector3=m.position
				race.weapons.step_missile(race,m,.01)
				check(m.launch_speed>=last_speed and m.launch_speed<=Race.Weapons.MISSILE_SPEED,"Motor accelerates monotonically to cruise")
				if not airborne: check(m.position.distance_to(previous)<6.,"Road launch does not teleport")
				last_speed=m.launch_speed
			check(is_equal_approx(m.launch_speed,Race.Weapons.MISSILE_SPEED),"Motor reaches full cruise speed")
	var race:=Race.new([{"slot":0},{"slot":1}],31)
	var p:Dictionary=race.racers[1];p.distance=100.;race.racers[0].distance=180.
	var vfx:=Vfx.new();root.add_child(vfx);vfx.configure(race)
	for kind in ["missile","drone","warp","emp","jammer"]:
		p.weapon=kind;vfx.update()
		check(vfx.turrets[1].visible==(kind=="drone"),"Held sentry is mounted before activation")
		check(vfx.dishes[1].visible==(kind=="jammer"),"Held jammer is visible folded")
		for key in vfx.mounts[1]: check(vfx.mounts[1][key].visible==(kind==key),"Only equipped inactive module is shown")
	p.weapon="drone";race.weapons.activate(race,1);p.drone_target=0;vfx.update()
	var head:Node3D=vfx.turrets[1].get_meta("head")
	check(head.global_position.distance_to(Race.Weapons.drone_position(race,p))<.001,"Sentry aim pivot remains attached to hull")
	var direction:Vector3=(Race.Weapons.pose(race,race.racers[0]).origin-head.global_position).normalized()
	check(head.global_basis.z.dot(direction)>.999,"Mounted turret aims at its target")
	p.drone_target=-1;race.vfx_clock=1.2-p.slot*.11+.08;vfx.update()
	var scanning_basis:=head.basis
	var led:MeshInstance3D=vfx.turrets[1].get_meta("status_led")
	check(led.material_override.emission_energy_multiplier>0.,"Activated sentry blinks its status LED")
	race.vfx_clock+=.6;vfx.update()
	check(not head.basis.is_equal_approx(scanning_basis),"Activated sentry scans when no rival is in range")
	check(led.material_override.emission_energy_multiplier==0.,"Status LED has a distinct off phase")
	p.drone_time=0.;p.weapon="drone";vfx.update();var stowed_basis:=head.basis
	race.vfx_clock+=1.;vfx.update()
	check(head.basis.is_equal_approx(stowed_basis) and led.material_override.emission_energy_multiplier==0.,"Held pickup stays stowed with LED off")
	p.weapon="missile";race.weapons.activate(race,1)
	var rocket:Dictionary=race.weapons.missiles[0];rocket.age=.15;vfx.update()
	var motor:Node3D=vfx.missile_nodes[rocket.id]
	check(not motor.get_meta("engine").visible and motor.get_meta("motor_light").light_energy==0.,"Rack ejection precedes motor ignition")
	rocket.age=.7;vfx.update()
	check(motor.get_meta("engine").visible and motor.get_meta("motor_flare").get_shader_parameter("power")>1. and motor.get_meta("motor_light").light_energy>7.,"Ignited missile powers flare, core and nearby lighting")
	rocket.disabled=true;vfx.update()
	check(not motor.get_meta("engine").visible and motor.get_meta("motor_light").light_energy==0. and motor.get_meta("motor_flare").get_shader_parameter("power")==0.,"EMP extinguishes the complete rocket engine effect")
	p.crashed=true;vfx.update()
	check(not vfx.turrets[1].visible and not vfx.dishes[1].visible and vfx.mounts[1].values().all(func(n):return not n.visible),"Crash hides mounted weapons")
	vfx.queue_free();await process_frame
	if "--render" in OS.get_cmdline_user_args(): await render_scene()
	print("MOUNTED_WEAPON_TESTS %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func render_scene()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game)
	game.human_count=1;game.next_seed=31;game.start_local()
	game.set_process(false);game.set_physics_process(false)
	var p:Dictionary=game.race.racers[0];p.distance=150.;p.startup=1.;p.engine_power=.15
	game.race.countdown=0.;game.race.clock=12.;game.race.vfx_clock=12.
	var frame:=Race.Weapons.pose(game.race,p)
	var camera:Camera3D=game.views[0].camera
	camera.position=frame*Vector3(10.,7.,-13.);camera.look_at(frame*Vector3(0,1,0),frame.basis.y);camera.fov=55.
	for kind in ["missile","drone","warp","emp","jammer"]:
		p.weapon=kind;game.world.update_ships()
		game.views[0].hud.queue_redraw()
		await capture("mounted-"+kind)
	p.weapon="drone";game.race.weapons.activate(game.race,0);p.drone_target=-1
	game.race.vfx_clock=12.08;game.world.update_ships();game.views[0].hud.queue_redraw()
	await capture("sentry-scanning")
	p.drone_time=0.
	p.weapon="missile";game.race.racers[1].distance=2000.;game.race.weapons.activate(game.race,0)
	game.views[0].hud.queue_redraw()
	var m:Dictionary=game.race.weapons.missiles[0]
	for phase in [.22,.55]:
		while m.age<phase: game.race.weapons.step_missile(game.race,m,.01)
		game.world.update_ships();camera.position=frame*Vector3(15.,12.,-20.)
		camera.look_at(frame.origin.lerp(m.position,.5),frame.basis.y);camera.fov=65.
		await capture("missile-launch-%.2f"%phase)
	game.queue_free();await process_frame
func capture(name_value:String)->void:
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/"+name_value+".png")
