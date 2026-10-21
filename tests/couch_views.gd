extends SceneTree
## Moving on the couch in the lobby (players[].couch) slides the split-screen
## views over without restarting the race.
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func _initialize()->void:
	root.unfocusable=true;call_deferred("run")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.human_count=2;game.biome="city";game.next_seed=31;game.start_local()
	game.running=false;game.set_process(false);game.set_physics_process(false)
	var race:Variant=game.race
	var top:Vector2=game.views[0].holder.position
	var bottom:Vector2=game.views[1].holder.position
	check(top.y<bottom.y,"Without couch places, seat order")
	game.update_details([{"id":"0","couch":1},{"id":"1","couch":0}])
	check(game.race==race,"The race goes on")
	check(game.views[0].holder.position==bottom and game.views[1].holder.position==top,"The views trade places")
	game.update_details([{"id":"0","couch":0},{"id":"1","couch":1}])
	check(game.views[0].holder.position==top,"And back")
	game.queue_free();await process_frame
	print("COUCH_VIEWS_TESTS failures=",failures);quit(1 if failures else 0)
