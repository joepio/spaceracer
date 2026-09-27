extends SceneTree
const Track=preload("res://src/track.gd")
var game:Node
const OUTPUT="C:/dev/ion-rush-captures/gi"
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func run()->void:
	game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	for seed_value in [31,33,37]:
		game.human_count=1;game.next_seed=seed_value;game.difficulty="hard";game.start_local()
		game.running=false;game.set_process(false);game.set_physics_process(false)
		game.race.countdown=0.;game.race.clock=20.;game.race.vfx_clock=20.
		var shots:Array=[]
		for c in game.race.track.components:
			var distance:=0.
			for i in range(game.race.track.nodes.size()):
				if game.race.track.nodes[i].u>=lerpf(c.start,c.end,.25): distance=i*game.race.track.step;break
			shots.append([c.kind,distance,true])
		for h in game.race.track.dead_ends: shots.append(["wall" if h.wall else "drop",h.distance-180.,false])
		if seed_value==31: shots.append(["turbo",game.race.track.jumps[0].takeoff-100.,false])
		for shot in shots:
			for p in game.race.racers:
				p.distance=shot[1]-p.slot*25.;p.x=0.;p.speed=200.;p.startup=1.;p.engine_power=1.;p.thrust=1.
				var n:Dictionary=game.race.track.sample(p.distance)
				if n.split_gap>.01: p.x=n.preferred_route*(n.split_gap+(n.width-n.split_gap)*.5)
			game.world.update_ships()
			for view in game.views:
				game.world.update_camera(view.camera,view.index,0.,true)
				if shot[2]:
					var n:Dictionary=game.race.track.sample(shot[1])
					view.camera.position=n.p+n.frame.x*300.+Vector3.UP*320.-n.frame.z*200.
					view.camera.look_at(n.p+Vector3.UP*30.)
				view.hud.queue_redraw()
			for frame in range(35): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT+"/component-"+str(seed_value)+"-"+shot[0]+".png")
			print("COMPONENT_CAPTURE ",seed_value," ",shot[0])
	game.queue_free();await process_frame;quit()
