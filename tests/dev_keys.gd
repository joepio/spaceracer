extends SceneTree
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func press(game:Node,key:int,repeat:bool=false)->void:
	var event:=InputEventKey.new();event.keycode=key;event.physical_keycode=key;event.pressed=true;event.echo=repeat
	game._input(event)
func _initialize()->void: call_deferred("run")
func run()->void:
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.next_seed=31;game.start_local();game.set_process(false);game.set_physics_process(false)
	game.race.countdown=0.
	press(game,KEY_D);check(game.race.weapons.bombs.is_empty(),"Ordinary D does not cheat")
	press(game,KEY_F8);check(game.cheats.enabled and game.dev_label.visible,"F8 visibly enables dev mode")
	press(game,KEY_D,true);check(game.race.racers.all(func(p):return p.weapon==""),"OS key-repeat ignored")
	press(game,KEY_D);check(game.race.racers.all(func(p):return p.weapon=="bomb"),"Key D equips all racers")
	check(game.race.weapons.bombs.is_empty(),"Giving an item never fires it")
	press(game,KEY_G);check(game.race.racers.all(func(p):return p.weapon=="railgun") and game.race.weapons.rail_shots.is_empty(),"G equips railguns without firing")
	press(game,KEY_F8);check(not game.cheats.enabled and not game.dev_label.visible,"F8 turns cheats off")
	var count:int=game.race.weapons.bombs.size();press(game,KEY_E)
	check(game.race.weapons.pulses.is_empty() and game.race.weapons.bombs.size()==count,"Disabled mode protects ordinary driving")
	game.queue_free();await process_frame
	print("DEV_KEY_TESTS failures=",failures);quit(1 if failures else 0)
