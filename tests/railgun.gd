extends SceneTree
const Race=preload("res://src/race.gd")
const Rail=preload("res://src/railgun.gd")
const Obstacles=preload("res://src/obstacles.gd")
const Hud=preload("res://src/hud.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func reset(race:RefCounted)->void:
	race.track.obstacles=null;race.weapons.rail_shots.clear()
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		p.airborne=true;p.air_frame=Basis.IDENTITY;p.air_position=Vector3(0,2500,i*70.)
		p.air_velocity=Vector3(0,0,200);p.speed=200.;p.energy=100.;p.weapon_guard=0.;p.recovery=0.;p.crashed=false;p.finished=false
		p.emp_time=0.;p.drone_time=0.;p.warp_time=0.;p.weapon="railgun" if i==0 else ""
		p.rail_armed=false;p.rail_hold=0.;p.rail_view={};p.fire_held=false
func _initialize()->void: call_deferred("run")
func run()->void:
	var race:=Race.new([{"slot":0},{"slot":1},{"slot":2}],31,3,"hard","city")
	race.countdown=0.;race.clock=5.
	reset(race)
	var started:=Time.get_ticks_usec()
	check(race.weapons.activate(race,0),"Railgun fires")
	print("RAIL_TRACE_US ",Time.get_ticks_usec()-started)
	check(race.racers[1].energy==50. and race.racers[2].energy==100.,"Single first hit removes exactly half full energy")
	check(race.racers[0].weapon=="" and not race.weapons.activate(race,0),"One shot consumes the item")
	check(race.weapons.rail_shots.size()==1,"A single beam is emitted")
	reset(race);race.racers[1].air_position.x=15.;race.racers[2].air_position.z=-100.
	race.weapons.activate(race,0)
	check(race.racers[1].energy==100. and race.racers[2].energy==100.,"Outside aim cone and targets behind are missed")
	reset(race);race.racers[1].air_position.z=Rail.RANGE+20.;race.racers[2].air_position.z=-100.
	race.weapons.activate(race,0);check(race.racers[1].energy==100.,"Finite range")
	reset(race)
	var wall:=Obstacles.new();race.track.obstacles=wall
	wall.add_box(Transform3D(Basis.IDENTITY.scaled(Vector3(30,20,1)),Vector3(0,2500,30)))
	race.weapons.activate(race,0)
	check(race.racers[1].energy==100. and race.weapons.rail_shots[0].to.z<31.,"Scenery blocks shot and ends beam")
	reset(race);race.racers[0].air_frame=Basis(Vector3.UP,PI*.5)
	race.racers[1].air_position=Vector3(70,2500,0)
	race.weapons.activate(race,0);check(race.racers[1].energy==50.,"Shot follows physical nose orientation")
	reset(race);race.racers[0].emp_time=1.
	check(not race.weapons.activate(race,0) and race.racers[0].weapon=="railgun","EMP prevents firing without consuming")
	reset(race);race.racers[0].drone_time=2.
	check(not race.weapons.activate(race,0),"One active plus one stored: cannot fire until sentry ends")
	var slots:=Hud.item_slots(race.racers[0])
	check(slots.size()==2 and slots[0].state=="ACTIVE" and slots[1].text=="STORED · RAILGUN","HUD displays active sentry and queued railgun")
	race.racers[0].drone_time=0.
	check(Hud.item_slots(race.racers[0])[0].state=="READY" and race.weapons.activate(race,0),"Stored item becomes usable after active expires")
	reset(race);race.racers[1].energy=49.
	race.weapons.activate(race,0);check(race.racers[1].crashed,"Lethal damage uses normal crash behavior")
	reset(race);race.racers[1].weapon_guard=1.
	race.weapons.activate(race,0);check(race.racers[1].energy==100.,"Respawn/hit protection respected")
	reset(race)
	var found:=0
	for i in range(2000):
		if race.weapons.choose(3,6,400.)=="railgun": found+=1
	check(found>70 and found<300,"Railgun is in normal pickup pool")
	# An unactivated stored item blocks pickup; an active sentry leaves storage free.
	var p:Dictionary=race.racers[0];p.airborne=false;p.weapon="drone"
	var row:Dictionary=race.weapons.pickups[1]
	p.weapon_before=row.distance-10.;p.distance=row.distance+10.;p.weapon_x_before=row.x;p.x=row.x
	race.weapons.collect(race,p)
	check(p.weapon=="drone" and row.cooldown==0.,"Unactivated item occupies storage")
	p.weapon="";p.drone_time=3.;race.weapons.collect(race,p)
	check(not p.weapon.is_empty() and row.cooldown>0. and Hud.item_slots(p).size()==2,"Active sentry permits one visible stored pickup")
	reset(race)
	race.weapons.begin_step(race,.016,[{},{},{}])
	check(race.weapons.rail_shots.is_empty() and p.rail_armed and p.rail_preview.target==1,"Equipped railgun automatically shows its current target without pressing X")
	race.weapons.begin_step(race,.016,[{"fire":true},{},{}])
	check(race.weapons.rail_shots.size()==1 and p.weapon=="" and not p.rail_armed,"X press fires once immediately")
	for i in range(20): race.weapons.begin_step(race,.016,[{"fire":true},{},{}])
	race.weapons.begin_step(race,.016,[{"fire":false},{},{}])
	check(race.weapons.rail_shots.size()==1,"Holding and releasing do not fire another shot")
	reset(race);race.weapons.begin_step(race,.016,[{},{},{}]);p.emp_time=1.
	race.weapons.begin_step(race,.016,[{"fire":true},{},{}])
	check(race.weapons.rail_shots.is_empty() and p.weapon=="railgun" and not p.rail_armed and p.rail_preview.is_empty(),"EMP hides targeting and blocks fire without consuming the item")
	reset(race)
	var blocker:=Obstacles.new();race.track.obstacles=blocker
	blocker.add_box(Transform3D(Basis.IDENTITY.scaled(Vector3(30,20,1)),Vector3(0,2500,30)))
	race.weapons.begin_step(race,.016,[{},{},{}])
	check(p.rail_preview.target==-1,"Always-on target indicator respects walls")
	reset(race);p.weapon="emp"
	race.weapons.begin_step(race,.016,[{"fire":true},{},{}])
	check(p.weapon=="" and not race.weapons.pulses.is_empty(),"Other items still activate on press")
	var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=72.
	camera.position=Vector3(0,2508,-22);camera.look_at(Vector3(0,2501,150))
	for dimensions in [Vector2i(1600,900),Vector2i(1600,450),Vector2i(800,450)]:
		root.size=dimensions
		reset(race)
		var aim:=Rail.view_context(race,0,camera)
		var inside:=camera.project_position(aim.screen+Vector2(aim.pixels*.8,0),100.)
		race.racers[1].air_position=inside-Vector3(0,.6,0);race.racers[2].air_position.z=-100.
		p.rail_view=aim
		check(Rail.trace(race,0).target==1,"Inside the displayed circle hits at viewport %s"%dimensions)
		var outside:=camera.project_position(aim.screen+Vector2(aim.pixels*1.6,0),100.)
		race.racers[1].air_position=outside-Vector3(0,.6,0)
		check(Rail.trace(race,0).target==-1,"Outside the displayed circle misses at viewport %s"%dimensions)
		# Tap uses the same camera-matched aim tolerance as the visible guide.
		race.racers[1].air_position=inside-Vector3(0,.6,0)
		race.weapons.begin_step(race,.016,[{"fire":true,"rail_view":aim},{},{}])
		race.weapons.begin_step(race,.016,[{"fire":false,"rail_view":aim},{},{}])
		check(race.racers[1].energy==50.,"Quick tap also gets circle hit tolerance")
	camera.free()
	print("RAILGUN_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
