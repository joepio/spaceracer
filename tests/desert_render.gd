extends SceneTree
## Captures the desert biome: canyon run, sandworm breach, arch and overview.
## godot --path . --script res://tests/desert_render.gd -- --output=/abs/dir --seed=31
var game:Node
var output:=""
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func shot(label:String,camera:Transform3D=Transform3D(),hud:bool=true)->void:
	game.world.update_ships()
	for view in game.views:
		game.world.update_camera(view.camera,view.index,0.,true)
		if camera!=Transform3D(): view.camera.global_transform=camera
		view.hud.visible=hud
		view.hud.queue_redraw()
	for frame in range(24): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
	print("DESERT_CAPTURE ",label)
func place(distance:float)->void:
	for p in game.race.racers:
		p.distance=distance-p.slot*16.;p.speed=220.;p.x=(p.slot%3-1)*7.;p.heading=0.;p.slip=0.
		p.airborne=false;p.recovery=0.;p.lift=0.;p.lift_speed=0.;p.unload=0.;p.trim=0.
		p.startup=1.;p.engine_power=1.;p.thrust=1.;p.finished=false;p.crashed=false
func erupt(site_index:int,age:float)->void:
	var worm:RefCounted=game.world.scenery.worm
	worm.sites[site_index].start=game.race.clock-age
	worm.active=site_index
	worm.last_time=game.race.clock
func look(from:Vector3,to:Vector3)->Transform3D:
	return Transform3D.IDENTITY.translated(from).looking_at(to,Vector3.UP)
func run()->void:
	var seed_value:=31
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--seed="): seed_value=int(arg.trim_prefix("--seed="))
	if output.is_empty(): output=ProjectSettings.globalize_path("res://build/desert")
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false);game.set_physics_process(false)
	game.biome="desert";game.difficulty="normal";game.next_seed=seed_value;game.human_count=1;game.start_local()
	game.running=false;game.race.countdown=0.;game.race.clock=30.;game.race.over=false
	var track:RefCounted=game.race.track
	var desert:RefCounted=game.world.scenery
	var worm:RefCounted=desert.worm
	print("DESERT_RENDER sites=",worm.sites.size()," arches=",desert.arches.size())
	# 1. The worm arcs over the road as the pack arrives.
	if not worm.sites.is_empty():
		var site:Dictionary=worm.sites[0]
		place(site.distance-170.)
		var crown:float=(site.total*.5-site.lead)/worm.SPEED
		erupt(0,crown+.9)
		await shot("worm_chase")
		var n:Dictionary=track.sample(site.distance)
		var side:Vector3=site.across
		var along:Vector3=side.cross(Vector3.UP).normalized()
		var eye:Vector3=n.p-along*330.+side*90.+Vector3.UP*35.
		erupt(0,crown+.4)
		await shot("worm_wide",look(eye,n.p+Vector3.UP*55.),false)
		erupt(0,(site.surface_a-site.lead)/worm.SPEED+.6)
		eye=site.hole_a-along*190.-side*90.+Vector3.UP*75.
		await shot("worm_breach",look(eye,site.hole_a+Vector3.UP*40.),false)
	# 2. The deepest canyon on the lap.
	var best:=0;var best_height:=-INF
	for i in range(0,track.nodes.size(),4):
		var n:Dictionary=track.nodes[i]
		if n.feature!="ribbon" and n.feature!="open": continue
		var side:Vector3=-n.frame.x;side.y=0.;side=side.normalized()
		var left:Vector3=n.p+side*130.;var right:Vector3=n.p-side*130.
		var height:float=minf(desert.terrain.height_at(left.x,left.z),desert.terrain.height_at(right.x,right.z))-n.p.y
		if height>best_height: best_height=height;best=i
	place(best*track.step-60.)
	await shot("canyon_chase")
	# 3. Through a sandstone arch.
	if not desert.arches.is_empty():
		var arch:Dictionary=desert.arches[0]
		var index:=0;var closest:=INF
		for i in range(track.nodes.size()):
			var d:float=track.nodes[i].p.distance_to(arch.origin)
			if d<closest: closest=d;index=i
		place(index*track.step-150.)
		await shot("arch_chase")
		var n:Dictionary=track.nodes[index]
		var forward:Vector3=n.frame.z;forward.y=0.;forward=forward.normalized()
		await shot("arch_wide",look(arch.origin-forward*260.+Vector3.UP*60.+(-n.frame.x)*80.,arch.origin+Vector3.UP*40.),false)
	# 4. An aerial overview of dunes, mesas and the course.
	var center:Vector3=track.sample(track.length*.3).p
	await shot("overview",look(center+Vector3(700.,520.,700.),center),false)
	game.queue_free()
	await process_frame
	quit()
