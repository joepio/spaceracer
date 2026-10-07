extends SceneTree
## Captures the ocean: chase shots, a giant octopus, a jellyfish swarm and an overview.
## godot --path . --script res://tests/ocean_render.gd -- --output=/abs/dir --seed=31
var game:Node
var output:=""
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func shot(label:String,camera:Transform3D=Transform3D(),hud:bool=true)->void:
	game.world.update_ships()
	game.world.scenery.animate(game.race.clock)
	for view in game.views:
		game.world.update_camera(view.camera,view.index,0.,true)
		if camera!=Transform3D(): view.camera.global_transform=camera
		view.hud.visible=hud
		view.hud.queue_redraw()
	for frame in range(24): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
	print("OCEAN_CAPTURE ",label)
func place(distance:float)->void:
	for p in game.race.racers:
		p.distance=distance-p.slot*16.;p.speed=220.;p.x=(p.slot%3-1)*7.;p.heading=0.;p.slip=0.
		p.airborne=false;p.recovery=0.;p.lift=0.;p.lift_speed=0.;p.unload=0.;p.trim=0.
		p.startup=1.;p.engine_power=1.;p.thrust=1.;p.finished=false;p.crashed=false
func look(from:Vector3,to:Vector3)->Transform3D:
	return Transform3D.IDENTITY.translated(from).looking_at(to,Vector3.UP)
func nearest(point:Vector3)->int:
	var track:RefCounted=game.race.track
	var index:=0;var closest:=INF
	for i in range(track.nodes.size()):
		var d:float=track.nodes[i].p.distance_to(point)
		if d<closest: closest=d;index=i
	return index
func run()->void:
	var seed_value:=31
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--seed="): seed_value=int(arg.trim_prefix("--seed="))
	if output.is_empty(): output=ProjectSettings.globalize_path("res://build/ocean")
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false);game.set_physics_process(false)
	game.biome="ocean";game.difficulty="normal";game.next_seed=seed_value;game.human_count=1;game.start_local()
	game.running=false;game.race.countdown=0.;game.race.clock=30.;game.race.over=false
	var track:RefCounted=game.race.track
	var life:RefCounted=game.world.scenery.life
	for fraction in [.08,.3,.62]:
		place(track.length*fraction)
		await shot("chase_%02d"%roundi(fraction*100.))
	if not life.octopuses.is_empty():
		var octopus:Dictionary=life.octopuses[0]
		var index:=nearest(octopus.position)
		place(index*track.step-120.)
		await shot("octopus_chase")
		var n:Dictionary=track.nodes[index]
		var target:Vector3=octopus.position+Vector3.UP*octopus.size*1.6
		var eye:Vector3=n.p+Vector3.UP*20.+(n.p-target).normalized()*30.
		await shot("octopus_wide",look(eye,target),false)
	if not life.jellies.is_empty():
		var jelly:Dictionary=life.jellies[0]
		var index:=nearest(jelly.home)
		var n:Dictionary=track.nodes[index]
		await shot("jellies",look(n.p+Vector3.UP*12.,jelly.home),false)
	# The closest lantern weed and sea fan to the course, seen from the road.
	var scenery:RefCounted=game.world.scenery
	for kind in [scenery.LANTERN,scenery.FAN]:
		var best:Dictionary={};var best_distance:=INF
		for plant in scenery.plants:
			if plant.kind!=kind: continue
			var p:Vector3=plant.transform.origin
			var n:Dictionary=track.nodes[nearest(p)]
			var d:=Vector2(p.x-n.p.x,p.z-n.p.z).length()
			if d>60. and d<best_distance: best_distance=d;best=plant
		if best.is_empty(): continue
		var origin:Vector3=best.transform.origin
		var height:float=best.transform.basis.get_scale().y
		var n:Dictionary=track.nodes[nearest(origin)]
		var toward:=Vector3(n.p.x-origin.x,0.,n.p.z-origin.z).normalized()
		var eye:Vector3=origin+toward*height*1.3+Vector3.UP*height*.6
		await shot("plant_%d"%kind,look(eye,origin+Vector3.UP*height*.45),false)
	var fish_center:Vector3=life.fish_positions[0]
	await shot("fish",look(fish_center+Vector3(28.,8.,28.),fish_center),false)
	var center:Vector3=track.sample(track.length*.3).p
	await shot("overview",look(center+Vector3(520.,430.,520.),center),false)
	game.queue_free()
	await process_frame
	quit()
