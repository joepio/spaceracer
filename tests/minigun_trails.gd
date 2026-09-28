extends SceneTree
const Race=preload("res://src/race.gd")
const Vfx=preload("res://src/weapon_vfx.gd")
const Trails=preload("res://src/boost_trails.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: root.unfocusable=true;call_deferred("run")
func fresh()->RefCounted:
	var race:=Race.new([{"slot":0},{"slot":1}],31)
	race.countdown=0.;race.clock=10.;race.weapons.pickups.clear()
	for i in range(2):
		var p:Dictionary=race.racers[i];p.distance=700.-i*60.;p.speed=200.;p.x=0.;p.startup=1.;p.ignited=true
	race.racers[1].weapon="drone";race.weapons.activate(race,1)
	race.weapons.begin_step(race,.001,[{},{}])
	return race
func run()->void:
	for hz in [30,60,120,240]:
		var race:=fresh();var p:Dictionary=race.racers[1];p.drone_cooldown=Race.Weapons.SENTRY_INTERVAL
		for tick in range(hz*3): race.weapons.end_step(race,1./hz)
		var damage:float=100.-race.racers[0].energy
		print("MINIGUN rate=",hz," damage/3s=",damage)
		check(absf(damage-30.)<=.51,"Sentry preserves 10 DPS at different physics rates")
		check(absf(race.racers[0].speed-200.*pow(.995,3./.4))<.15,"Rapid bullets preserve cumulative slowdown")
	var race:=fresh();var p:Dictionary=race.racers[1]
	race.racers[0].distance=5000.
	for tick in range(180): race.weapons.end_step(race,1./60.)
	race.racers[0].distance=p.distance+60.;race.weapons.end_step(race,1./60.)
	check(race.weapons.shots.size()==1,"Acquiring target cannot dump accumulated idle shots")
	var vfx:=Vfx.new();root.add_child(vfx);vfx.configure(race)
	check(vfx.tracers[0].visible and vfx.turrets[1].get_meta("muzzle").visible,"New round shows tracer and muzzle flash")
	vfx.update();check(vfx.tracers[0].visible,"Extra update in same frame preserves tracer for all views")
	var shown_frame:=Engine.get_process_frames()
	while Engine.get_process_frames()==shown_frame: await process_frame
	vfx.update()
	check(not vfx.tracers[0].visible and not vfx.turrets[1].get_meta("muzzle_light").visible,"Tracer and light disappear on next frame without a new shot")
	var trail:=Trails.new();root.add_child(trail)
	p.boost=1.;p.thrust=1.;p.braking=0.;p.speed=300.
	for tick in range(30):
		var t:=tick/60.
		trail.update_trail(Transform3D(Basis(Vector3.UP,t),Vector3(sin(t)*150.,0.,cos(t)*150.)),p,t,Color.CYAN)
	check(trail.visible and trail.history.size()>12,"Boost retains a continuous world-space light path")
	check(trail.history[0].pose.origin.distance_to(trail.history.back().pose.origin)>40.,"Trail follows travelled distance")
	p.boost=0.;trail.update_trail(trail.history[0].pose,p,1.,Color.CYAN)
	check(not trail.visible,"Trail fades away after boost ends")
	p.boost=1.;trail.update_trail(Transform3D.IDENTITY,p,1.1,Color.CYAN)
	trail.update_trail(Transform3D(Basis.IDENTITY,Vector3(0,0,5)),p,1.12,Color.CYAN)
	trail.update_trail(Transform3D(Basis.IDENTITY,Vector3(0,0,900)),p,1.14,Color.CYAN)
	check(not trail.visible and trail.history.size()==1,"Respawn teleport cannot draw a streak across the map")
	p.crashed=true;trail.update_trail(Transform3D.IDENTITY,p,1.16,Color.CYAN)
	check(trail.history.is_empty(),"Crash removes the live boost path")
	vfx.queue_free();trail.queue_free();await process_frame
	print("MINIGUN_TRAILS_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
