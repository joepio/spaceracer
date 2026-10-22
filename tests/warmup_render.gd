extends SceneTree
## Needs a GPU (not --headless). Loading draws every effect material off-screen,
## then the first missile and blast must not stall a frame on shader compiles.
## Pass `--no-warmup` to compare against the old behaviour.
var failures:=0
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func shader_paths(node:Node,out:Dictionary)->void:
	if node is GeometryInstance3D:
		var materials:Array=[node.material_override]
		if node is MeshInstance3D and node.mesh!=null:
			for i in range(node.mesh.get_surface_count()): materials.append(node.get_active_material(i))
		for material in materials:
			if material is ShaderMaterial and material.shader!=null: out[material.shader.resource_path.get_file()]=true
	for child in node.get_children(): shader_paths(child,out)
## Pipelines built in the middle of drawing a frame: the ones that stall it.
## Ubershaders hide most of them; specialization and surface compiles show
## the work that still lands in the frame where an effect first appears.
func draw_compiles()->int:
	var total:=0
	for info in [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION,RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE]:
		total+=RenderingServer.get_rendering_info(info)
	return total
func run()->void:
	var warm:=not ("--no-warmup" in OS.get_cmdline_user_args())
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	game.render_warmup=warm
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.human_count=1;game.next_seed=31;game.start_local()
	var warmup:Node=game.world.get_node_or_null("RenderWarmup")
	check((warmup!=null)==warm,"Race build starts the render warmup")
	if warmup!=null:
		var drawn:={}
		shader_paths(warmup,drawn)
		for name in ["missile_trail.gdshader","missile_laser.gdshader","blast_billow.gdshader","blast_embers.gdshader","blast_heat.gdshader","wreck_surface.gdshader","wreck_fire.gdshader","rail_beam.gdshader","emp.gdshader"]:
			check(drawn.has(name),"Warmup draws %s before the race"%name)
		print("WARMUP proxies=%d shaders=%d"%[warmup.proxies,drawn.size()])
	check(game.world.weapon_vfx.missile_pool.size()==game.world.weapon_vfx.SPARE_MISSILES,"Missiles are built during loading")
	for i in range(12): await process_frame
	check(game.world.get_node_or_null("RenderWarmup")==null,"Warmup frees itself after a few frames")
	game.set_process(false);game.set_physics_process(false)
	var race:RefCounted=game.race
	race.countdown=0.
	var baseline:=0.
	var last:=Time.get_ticks_usec()
	for i in range(6):
		game.world.update_ships()
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec();if i>0: baseline=maxf(baseline,(now-last)/1000.)
		last=now
	var compiles_before:=draw_compiles()
	race.racers[1].weapon="missile";race.weapons.activate(race,1)
	var missile:Dictionary=race.weapons.missiles[0]
	var frame:Transform3D=race.Weapons.pose(race,race.racers[0])
	missile.position=frame.origin+frame.basis*Vector3(6,5,30);missile.age=1.
	race.weapons.bursts.append({"id":991,"position":frame.origin+frame.basis*Vector3(0,3,40),"life":1.8,"size":16.})
	race.racers[0].crashed=true;race.racers[0].crash_id+=1;race.racers[0].air_position=frame.origin+frame.basis*Vector3(4,2,35)
	var worst:=0.
	var times:=[]
	for i in range(8):
		game.world.update_ships()
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec();worst=maxf(worst,(now-last)/1000.);times.append(roundi((now-last)/1000.));last=now
	check(game.world.weapon_vfx.missile_pool.size()==game.world.weapon_vfx.SPARE_MISSILES-1,"The first missile comes from the pool")
	var stalls:=draw_compiles()-compiles_before
	if warm: check(stalls==0,"First missile, blast and wreck compile no pipelines at draw time (%d)"%stalls)
	print("WARMUP_RENDER warm=%s draw_time_pipeline_compiles=%d baseline_worst_ms=%.0f first_effects_worst_ms=%.0f frames=%s failures=%d"%[warm,stalls,baseline,worst,times,failures])
	quit(1 if failures else 0)
