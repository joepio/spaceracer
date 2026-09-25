extends SceneTree
var game:Node
var output:="user://track-review"
func _initialize()->void:
	root.unfocusable=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")
func run()->void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.human_count=1;game.next_seed=31;game.start_local()
	game.running=false;game.set_process(false);game.set_physics_process(false)
	game.race.countdown=0.;game.race.clock=20.;game.race.vfx_clock=20.
	for example in [["open",.5,0.],["halfpipe",.5,.58],["tube",.12,0.],["tube",.5,0.],["tube",.5,.9],["tube",.88,0.],["split",.15,1.],["split",.5,-1.],["split",.88,1.]]:
		var indices:Array=[]
		for i in range(game.race.track.nodes.size()):
			if game.race.track.nodes[i].feature==example[0]: indices.append(i)
		var distance:float=indices[int((indices.size()-1)*example[1])]*game.race.track.step
		for i in range(game.race.racers.size()):
			var p:Dictionary=game.race.racers[i]
			p.distance=distance+i*35.
			var n:Dictionary=game.race.track.sample(p.distance)
			p.x=n.width*example[2] if example[0]!="split" else (n.split_gap+(n.width-n.split_gap)*.5)*(example[2] if i==0 else (1. if i%2==0 else -1.))
			p.speed=250.;p.startup=1.;p.engine_power=1.;p.thrust=1.;p.acceleration=95.
		game.race.vfx_clock+=.5
		game.world.update_ships()
		for view in game.views:
			game.world.update_camera(view.camera,view.index,0.,true)
			view.hud.queue_redraw()
		for frame in range(90): await process_frame
		await RenderingServer.frame_post_draw
		var label:="%s-%.2f-%.2f"%[example[0],example[1],example[2]]
		root.get_texture().get_image().save_png(output.path_join(label+".png"))
		print("TRACK_CAPTURE ",label)
	game.queue_free()
	await process_frame
	quit()
