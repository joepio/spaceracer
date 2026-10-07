extends SceneTree
## Chase shots around the lap plus an aerial overview, for any world.
## godot --path . --script res://tests/biome_render.gd -- --biome=forest --output=/abs/dir --seed=31
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
	print("BIOME_CAPTURE ",label)
func place(distance:float)->void:
	for p in game.race.racers:
		p.distance=distance-p.slot*16.;p.speed=220.;p.x=(p.slot%3-1)*7.;p.heading=0.;p.slip=0.
		p.airborne=false;p.recovery=0.;p.lift=0.;p.lift_speed=0.;p.unload=0.;p.trim=0.
		p.startup=1.;p.engine_power=1.;p.thrust=1.;p.finished=false;p.crashed=false
func run()->void:
	var seed_value:=31
	var biome:="city"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--seed="): seed_value=int(arg.trim_prefix("--seed="))
		if arg.begins_with("--biome="): biome=arg.trim_prefix("--biome=")
	if output.is_empty(): output=ProjectSettings.globalize_path("res://build/"+biome)
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false);game.set_physics_process(false)
	game.biome=biome;game.difficulty="normal";game.next_seed=seed_value;game.human_count=1;game.start_local()
	game.running=false;game.race.countdown=0.;game.race.clock=30.;game.race.over=false
	var track:RefCounted=game.race.track
	for fraction in [.08,.3,.62,.82]:
		place(track.length*fraction)
		await shot("chase_%02d"%roundi(fraction*100.))
	var center:Vector3=track.sample(track.length*.3).p
	await shot("overview",Transform3D.IDENTITY.translated(center+Vector3(600.,380.,600.)).looking_at(center,Vector3.UP),false)
	game.queue_free()
	await process_frame
	quit()
