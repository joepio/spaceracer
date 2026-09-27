extends SceneTree
const Race=preload("res://src/race.gd")
const Draft=preload("res://src/slipstream.gd")
class StraightRoad extends RefCounted:
	var length:=100000.
	var raised:=false
	func sample(distance:float)->Dictionary:
		return {"p":Vector3(0.,20. if raised and distance>115. else 0.,fposmod(distance,length)),"frame":Basis.IDENTITY,"width":100.,"curve":0.,"crest":0.,"slope":0.,"zone":"","air_gap":false}

var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func fresh()->RefCounted:
	var race:=Race.new([{"slot":2},{"slot":7},{"slot":11}],31)
	race.track=StraightRoad.new();race.countdown=0.;race.clock=5.
	race.weapons.pickups.clear();race.weapons.batteries.clear()
	for i in range(3):
		var p:Dictionary=race.racers[i]
		p.distance=100.+i*30.;p.x=0.;p.speed=265.;p.startup=1.;p.ignited=true;p.engine_power=1.
	return race
func _initialize()->void: call_deferred("run")
func run()->void:
	var race:=fresh();var p:Dictionary=race.racers[0]
	Draft.update(race,.1)
	check(p.slipstream>0. and p.slipstream<.3,"Wake builds progressively")
	Draft.update(race,.5)
	check(is_equal_approx(p.slipstream,1.) and race.racers[2].slipstream==0.,"Followers benefit; the front car does not")
	check(is_equal_approx(Draft.drag_multiplier(p,false),.74),"Several cars ahead never stack past 26 percent drag reduction")
	check(Draft.drag_multiplier(p,true)>.85,"Boost stacking has a smaller benefit")
	p.x=20.;Draft.update(race,.1)
	check(p.slipstream>0. and p.slipstream<1.,"Leaving wake fades smoothly")
	Draft.update(race,.3)
	check(p.slipstream==0.,"Adjacent lane gets no lasting draft")
	for field in ["airborne","crashed","finished","recovery","warp_time","emp_time"]:
		race=fresh();p=race.racers[0];p.slipstream=1.
		p[field]=true if field in ["airborne","crashed","finished"] else 1.
		Draft.update(race,.01)
		check(p.slipstream==0.,"Follower excluded during "+field)
		race=fresh();race.racers[2].distance=1000.
		race.racers[1][field]=true if field in ["airborne","crashed","finished"] else 1.
		Draft.update(race,1.)
		check(race.racers[0].slipstream==0.,"No wake from source during "+field)
	for scenario in ["distant","alongside","opposite","slow","overpass","countdown"]:
		race=fresh();race.racers[2].distance=1000.
		match scenario:
			"distant": race.racers[1].distance=300.
			"alongside": race.racers[1].distance=100.;race.racers[1].x=8.
			"opposite": race.racers[1].heading=PI
			"slow": race.racers[1].speed=50.
			"overpass": race.track.raised=true
			"countdown": race.countdown=1.
		Draft.update(race,1.)
		check(race.racers[0].slipstream==0.,"No false draft: "+scenario)
	# Same physical formation on different laps still provides a wake.
	race=fresh();race.racers[1].distance+=race.track.length;Draft.update(race,1.)
	check(race.racers[0].slipstream==1.,"Lapped traffic can be drafted")
	var ordered:=fresh();var reversed:=fresh();reversed.racers.reverse()
	ordered.step(.1,[{"throttle":1.},{"throttle":1.},{"throttle":1.}])
	reversed.step(.1,[{"throttle":1.},{"throttle":1.},{"throttle":1.}])
	for i in range(3):
		check(is_equal_approx(ordered.racers[i].speed,reversed.racers[2-i].speed),"Roster order cannot change slipstream acceleration")
	# Hold a leader 30 m ahead to measure sustained drag reduction independently
	# of overtaking or a random track's corners, hills and pads.
	for hz in [30,60,120]:
		race=fresh();p=race.racers[0]
		for tick in range(hz*8):
			race.racers[1].distance=p.distance+30.;race.racers[1].speed=320.
			race.racers[2].distance=p.distance+1000.
			race.step(1./hz,[{"throttle":1.},{"throttle":1.},{"throttle":1.}])
		check(p.speed>303. and p.speed<309.,"Draft raises terminal speed to about 308 m/s, Hz=%d"%hz)
		check(p.energy==100. and not p.airborne,"Draft spends no energy and remains grounded")
		var before:float=p.speed
		race.step(.05,[{"brake":1.},{},{}])
		check(p.speed<before-11.,"Brakes remain strong while drafting")
		for tick in range(hz*3):
			race.racers[1].x=30.
			race.step(1./hz,[{"throttle":1.},{"throttle":1.},{"throttle":1.}])
		check(p.slipstream==0. and p.speed<275.,"After passing/leaving wake speed settles toward normal")
	print("SLIPSTREAM_TESTS %d checks, %d failures"%[checks,failures])
	if "--render" in OS.get_cmdline_user_args(): await render_sample()
	quit(1 if failures else 0)

func render_sample()->void:
	root.unfocusable=true
	var game:Node=load("res://main.tscn").instantiate();root.add_child(game)
	game.human_count=2;game.next_seed=31;game.start_local()
	game.set_process(false);game.set_physics_process(false)
	game.race.countdown=0.;game.race.clock=12.
	for i in range(game.race.racers.size()):
		var p:Dictionary=game.race.racers[i]
		p.distance=game.race.track.length*.055+([0.,30.][i] if i<2 else 1000.+i*100.)
		p.x=0.;p.speed=300.;p.startup=1.;p.ignited=true;p.engine_power=1.;p.thrust=1.
	Draft.update(game.race,.5)
	check(game.race.racers[0].slipstream>.9 and game.race.racers[1].slipstream==0.,"Native seeded straight has follower-only drafting")
	game.world.update_ships()
	for view in game.views:
		game.world.update_camera(view.camera,view.index,0.,true)
		view.hud.visible=true;view.hud.queue_redraw()
	for frame in range(30): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/dev/ion-rush-captures/gi/slipstream.png")
	game.queue_free();await process_frame
	print("SLIPSTREAM_RENDER two-player visor capture, failures=",failures)
