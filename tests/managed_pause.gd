extends SceneTree

class TestBridge:
	extends "res://src/bridge.gd"
	var overlay_requests:=0
	var written:Dictionary={}
	func set_setting(key:String,value:Variant)->void: written[key]=value
	func _ready()->void: pass
	func _process(_dt:float)->void: pass
	func request_overlay()->void: overlay_requests+=1

var game:Node
var bridge:TestBridge
var failures:=0
var checks:=0

func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")

func check(value:bool,label:String)->void:
	checks+=1
	if not value:
		failures+=1
		push_error(label)

func frame(buttons:int,axes:Array=[])->void:
	bridge.frames={"pad-one":{"buttons":buttons,"axes":axes}}
	bridge.frame_at=Time.get_ticks_msec()
	game.process_pause(.1)
	game.navigate_menu(.35)

func press(button:int)->void:
	frame(0)
	frame(1 << button)
	frame(0)

func row(id:String)->Control:
	for control in game.menu_rows:
		if control.get_meta("menu_id")==id: return control
	return null

func run()->void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.start_local()
	game.bridge.free()
	bridge=TestBridge.new()
	bridge.launched_by_daemon=true
	bridge.phase="running"
	game.bridge=bridge
	game.add_child(bridge)
	game.roster[0].controller="pad-one"
	game.running=false
	game.start_managed("")
	check(game.running and not game.local_paused and not game.in_menu,"A GameNight session starts straight in the race, without a start menu")
	press(7)
	game.adjust_menu("bots",1)
	check(row("bots")!=null and bridge.written.get("bots")==game.settings.values.bots,"Changing the AI racers writes it back to the party")
	game.adjust_menu("bots",-1)
	press(7)
	game.managed_buttons.clear() # as after a fresh launch
	var original:RefCounted=game.race
	frame(1 << 7)
	check(game.running and not game.local_paused,"Held Start at launch cannot immediately pause")
	press(7)
	check(game.local_paused and not game.running and bridge.overlay_requests==0,"Host Start pauses inside the game, without opening lobby")
	check(row("sound")!=null and row("players")==null and row("random_race")==null,"Managed pause offers audio without replacing host player assignments")
	check(row("race").text=="Resume","Managed pause starts on Resume")
	check(row("biome")!=null and row("difficulty")!=null and row("laps")!=null and row("restart")!=null,"Managed pause offers the race settings and a restart")
	var biome_before:String=game.biome
	game.adjust_menu("biome",1)
	check(game.biome!=biome_before and bridge.written.get("biome")==game.biome,"Changing the world writes it back to the party")
	game.adjust_menu("laps",1)
	check(bridge.written.get("laps")==game.laps,"Changing laps writes it back to the party")
	game.adjust_menu("biome",-1)
	game.setting_changed("difficulty","hard")
	check(row("difficulty").text.ends_with("Hard"),"A setting changed in the app shows in the open menu")
	frame(0,[0,32767])
	frame(0)
	check(root.gui_get_focus_owner()==row("restart"),"Authoritative host stick moves down to Restart race, right under Resume")
	row("sound").grab_focus()
	var enabled:bool=game.sound_enabled
	press(0)
	check(game.sound_enabled!=enabled and AudioServer.is_bus_mute(0)==enabled,"Host A toggles the audio mute option")
	var native:=InputEventJoypadButton.new()
	native.button_index=JOY_BUTTON_A
	native.pressed=true
	Input.parse_input_event(native)
	await process_frame
	native.pressed=false
	Input.parse_input_event(native)
	await process_frame
	check(game.sound_enabled!=enabled,"Native A cannot double-activate the host-driven pause menu")
	frame(1 << 0)
	var after_press:bool=game.sound_enabled
	frame(1 << 0)
	check(game.sound_enabled==after_press,"Held A never repeatedly toggles audio")
	frame(0)
	frame(1 << 7)
	check(game.running and not game.local_paused and game.race==original,"Start resumes the existing race and roster")
	frame(1 << 7)
	check(game.running,"Held Start does not immediately pause again")
	press(7)
	press(6)
	check(bridge.overlay_requests==1 and game.local_paused,"Back requests the lobby even inside the pause menu")
	game.pause_managed("")
	bridge.phase="paused"
	press(7)
	check(not game.running,"Background game ignores Start while the host has paused it")
	bridge.phase="running"
	game.start_managed("")
	check(game.running and not game.local_paused and not game.in_menu,"Returning from lobby leaves no stuck pause menu")
	frame(1 << 6)
	check(bridge.overlay_requests==1,"Held Back on return cannot immediately reopen the lobby")
	frame(0)
	press(6)
	check(bridge.overlay_requests==2,"A fresh Back press returns to the lobby")
	press(7)
	game.difficulty="easy" if game.difficulty!="easy" else "hard"
	game.start_selected()
	check(game.race==original and game.running,"Changed host settings cannot replace managed controller assignments on Resume")
	press(7)
	var roster_before:Array=game.roster.duplicate(true)
	game.restart_managed_race()
	check(game.race!=original and game.race.track.difficulty==game.difficulty and game.running and not game.in_menu and game.roster==roster_before,"Restart race uses the new settings with the same roster")
	original=game.race
	press(7)
	frame(0,[0,32767])
	bridge.frame_at=Time.get_ticks_msec()-300
	game.process_managed_menu()
	check(game.menu_sticks.is_empty(),"Expired host input cannot keep navigating the pause menu")
	var focus_generation:int=game.managed_focus_generation
	check(game.managed_focus_allowed(bridge.session,focus_generation),"Current running host session may claim focus")
	check(game.managed_focus_should_retry(bridge.session,focus_generation,false),"An active restored window may retry focus")
	check(not game.managed_focus_should_retry(bridge.session,focus_generation,true),"Native focus success immediately stops retries")
	game.cancel_managed_focus()
	check(not game.managed_focus_allowed(bridge.session,focus_generation),"Native focus loss cancels outstanding focus attempts")
	check(not game.managed_focus_allowed("old-session",game.managed_focus_generation),"A stale session cannot reclaim focus")
	bridge.phase="paused"
	check(not game.managed_focus_allowed(bridge.session,game.managed_focus_generation),"Paused games cannot reclaim focus")
	focus_generation=game.managed_focus_generation
	game.pause_managed(bridge.session)
	check(game.managed_focus_generation!=focus_generation,"Pause invalidates an outstanding restore attempt")
	focus_generation=game.managed_focus_generation
	game.dispose_managed(bridge.session)
	check(game.managed_focus_generation!=focus_generation,"Dispose invalidates an outstanding restore attempt")
	print("MANAGED_PAUSE_TESTS %d checks, %d failures"%[checks,failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
