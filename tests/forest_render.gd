extends SceneTree
var times:Array[float]=[]
var cpu:Array[float]=[]
var gpu:Array[float]=[]
func _initialize()->void:
 root.unfocusable=true
 call_deferred("run")
func run()->void:
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 game.set_process(false)
 Engine.max_fps=0
 var tag:="forest"
 var output:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--tag="): tag=arg.trim_prefix("--tag=")
  if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
 var view=game.views[0]
 var n:Dictionary=game.race.track.sample(game.race.track.length*.07)
 view.camera.position=n.p+n.frame.x*150.+Vector3.UP*90.-n.frame.z*100.
 view.camera.look_at(n.p+n.frame.z*180.+Vector3.UP*20.,Vector3.UP)
 view.hud.visible=false
 RenderingServer.viewport_set_measure_render_time(view.viewport.get_viewport_rid(),true)
 for i in range(100): await process_frame
 var last:=Time.get_ticks_usec()
 for i in range(180):
  await process_frame
  var now:=Time.get_ticks_usec()
  times.append((now-last)/1000.)
  last=now
  cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(view.viewport.get_viewport_rid()))
  gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(view.viewport.get_viewport_rid()))
 await RenderingServer.frame_post_draw
 if output.is_empty(): output=ProjectSettings.globalize_path("res://build/forest-"+tag+".png")
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 root.get_texture().get_image().save_png(output)
 times.sort();cpu.sort();gpu.sort()
 print("FOREST_BENCH ",JSON.stringify({"tag":tag,"median_ms":times[90],"p95_ms":times[171],"cpu_ms":cpu[90],"gpu_ms":gpu[90],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"trees":game.world.scenery.trees.size(),"render_size":str(view.viewport.size)}))
 view={}
 game.queue_free()
 for i in range(3): await process_frame
 quit()
