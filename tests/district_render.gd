extends SceneTree
var game:Node
var capture_dir:="user://district-review"
func _initialize()->void:
	root.unfocusable=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir=arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	call_deferred("review")
func capture(name_value:String)->void:
	game.world.update_ships()
	for view in game.views:
		game.world.update_camera(view.camera,view.index,0,true)
		view.hud.queue_redraw()
	for settle in range(120): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name_value+".png"))
func review()->void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.human_count=1
	game.next_seed=31
	game.start_local()
	game.running=false
	game.race.countdown=0
	game.race.clock=20
	for racer in game.race.racers:
		racer.startup=1
		racer.engine_power=1
		racer.thrust=1
		racer.speed=250
	for example in [[.025,"entry"],[.045,"straight"],[.075,"avenue"],[.10,"city"]]:
		var distance:=0.0
		for i in range(game.race.track.nodes.size()):
			if game.race.track.nodes[i].u>=example[0]: distance=i*game.race.track.step;break
		for i in range(game.race.racers.size()): game.race.racers[i].distance=distance+i*50
		game.race.clock+=.6
		await capture(example[1])
	print("DISTRICT fixtures=",game.world.showpiece.fixtures.size()," probes=",game.world.showpiece.probes.size())
	print("CITY_RENDER buildings=",game.world.scenery.layout.buildings.size()," billboards=",game.world.scenery.layout.billboards.size()," cars=",game.world.scenery.traffic.instance_count," tunnel_lights=",game.world.tunnel_lights.size())
	game.queue_free()
	await process_frame
	quit()
