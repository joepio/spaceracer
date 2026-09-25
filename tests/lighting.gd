extends SceneTree
var failures:=0
var checks:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.human_count=4
	game.next_seed=31
	game.start_local()
	game.set_process(false)
	game.set_physics_process(false)
	# Exercise selection even on headless CI, where no GPU renderer is available.
	game.world.advanced_renderer=true
	for i in range(4): game.race.racers[i].distance=game.race.track.length*(.015+i*.025)
	game.world.set_quality(1.,4)
	game.world.update_ships()
	var lights:Array=game.world.showpiece.lights+game.world.scenery.local_lights
	var active:=0
	for light in lights:
		if light.shadow_enabled: active+=1
	check(active>0 and active<=8,"At most two shadow lights per player, shared between nearby players")
	check(not game.world.scene_environment.ssil_enabled and game.world.scene_environment.volumetric_fog_enabled,"High keeps atmospheric fog without the negligible SSIL pass")
	game.world.set_quality(.6,4)
	game.world.update_ships()
	for light in lights: check(not light.shadow_enabled,"Performance clears previous shadow allocation immediately")
	check(not game.world.scene_environment.ssr_enabled and not game.world.scene_environment.ssil_enabled and not game.world.scene_environment.volumetric_fog_enabled,"Performance disables expensive screen effects")
	game.world.set_quality(.8,4)
	game.world.update_ships()
	check(game.world.scene_environment.ssr_enabled and not game.world.scene_environment.ssil_enabled,"Balanced retains reflections with reduced lighting cost")
	for material in game.world.road_sections:
		check(int(material.get_shader_parameter("box_count"))<=24 and int(material.get_shader_parameter("sign_count"))<=4,"Reflection geometry stays bounded per road section")
	check(game.world.find_children("*","Label3D",true,false).all(func(label):return not "CITY NETWORK" in label.text),"Floating text advertisements are absent")
	game.queue_free()
	await process_frame
	print("LIGHTING_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
