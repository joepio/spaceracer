extends SceneTree
const Race=preload("res://src/race.gd")
const Bomb=preload("res://src/dive_bomb.gd")
const Obstacles=preload("res://src/obstacles.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func setup()->RefCounted:
	var race:=Race.new([{"slot":0},{"slot":1}],31)
	race.countdown=0.;race.clock=20.
	race.track.obstacles=Obstacles.new();race.track.hazards=null
	race.track.obstacles.add_box(Transform3D.IDENTITY,AABB(Vector3(-4000,699,-4000),Vector3(8000,1,8000)))
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		p.airborne=true;p.air_frame=Basis(Vector3.RIGHT,.2);p.air_velocity=Vector3(0,-45,230)
		p.air_position=Vector3(i*2000,850,0);p.weapon_guard=0.;p.recovery=0.;p.speed=p.air_velocity.length()
	race.racers[0].weapon="bomb"
	return race
func run()->void:
	for moving in [false,true]:
		var race:=setup();var p:Dictionary=race.racers[0];var target:Dictionary=race.racers[1]
		var aim:=Bomb.preview(race,p)
		check(aim.landed and aim.target==-1,"Prediction lands on visible scenery without inventing a target")
		target.air_velocity=Vector3(0,0,170.) if moving else Vector3.ZERO
		target.air_position=aim.position+Vector3(115,3,0)-target.air_velocity*aim.time
		aim=Bomb.preview(race,p)
		check(aim.target==1,"Enemy predicted inside the footprint locks")
		Bomb.input_step(race.weapons,race,0,false,.1);p.fire_held=false
		check(p.bomb_armed and not p.bomb_preview.is_empty() and race.weapons.bombs.is_empty(),"Flight automatically previews without holding X")
		Bomb.input_step(race.weapons,race,0,true,.01);p.fire_held=true
		check(race.weapons.bombs.size()==1 and p.weapon=="" and not p.bomb_armed,"X press launches exactly one payload")
		var b:Dictionary=race.weapons.bombs[0]
		check(b.target==1,"Launched bomb retains acquired enemy")
		var min_range:=INF
		for i in range(720):
			if race.weapons.bombs.is_empty(): break
			target.air_position+=target.air_velocity/120.
			min_range=minf(min_range,b.position.distance_to(target.air_position))
			Bomb.step(race.weapons,race,b,1./120.)
		print("GUIDED moving=",moving," min_range=",min_range," target_energy=",target.energy," age=",b.age)
		check(target.energy<50. or target.crashed,"Well-aimed glide seriously hits target")
	for turn in [-.35,.35,.6]:
		var turning_race:=setup();var launcher:Dictionary=turning_race.racers[0];var rival:Dictionary=turning_race.racers[1]
		var forecast:=Bomb.preview(turning_race,launcher)
		rival.air_velocity=Vector3(0,0,185.)
		rival.air_position=forecast.position+Vector3(signf(turn)*125.,3.,0)-rival.air_velocity*forecast.time
		check(Bomb.preview(turning_race,launcher).target==1,"Wide-offset turning target initially acquires")
		turning_race.weapons.activate(turning_race,0)
		var guided:Dictionary=turning_race.weapons.bombs[0]
		for tick in range(720):
			if turning_race.weapons.bombs.is_empty(): break
			rival.air_velocity=Basis(Vector3.UP,turn/120.)*rival.air_velocity
			rival.air_position+=rival.air_velocity/120.
			Bomb.step(turning_race.weapons,turning_race,guided,1./120.)
		print("GLIDE_TURN radians/sec=",turn," energy=",rival.energy)
		check(rival.energy<50.,"Locked bomb seriously hits a rival changing direction after launch")
	var race:=setup();var p:Dictionary=race.racers[0];var target:Dictionary=race.racers[1]
	var aim:=Bomb.preview(race,p)
	target.air_velocity=Vector3.ZERO;target.air_position=p.air_position+Vector3(500,0,80)
	check(Bomb.preview(race,p).target==-1,"Enemy well outside the forward aiming cone gets no automatic lock")
	var v:=Vector3(0,0,240.)
	var next:=Bomb.velocity_step(v,Vector3(1000,0,0),Vector3.ZERO,true,.1)
	check((v+Bomb.GRAVITY*.1).angle_to(next)<=Bomb.TURN_RATE*.1+.0001,"Guidance obeys maximum turn rate")
	Bomb.input_step(race.weapons,race,0,false,.1);p.fire_held=false;p.airborne=false
	Bomb.input_step(race.weapons,race,0,true,.1)
	check(p.weapon=="bomb" and race.weapons.bombs.is_empty() and not p.bomb_armed,"Landing while aiming cancels release and retains item")
	p.airborne=true;p.fire_held=false
	Bomb.input_step(race.weapons,race,0,false,.1);p.fire_held=false;p.emp_time=1.
	Bomb.input_step(race.weapons,race,0,true,.1)
	check(p.weapon=="bomb" and race.weapons.bombs.is_empty() and not p.bomb_armed,"EMP cancels aim without firing")
	p.emp_time=0.;race.weapons.activate(race,0)
	var b:Dictionary=race.weapons.bombs[0];b.target=1
	target.air_position=b.position-Vector3(0,0,100)
	Bomb.step(race.weapons,race,b,.01)
	check(b.target==-1,"Enemy escaping the forward seeker breaks lock")
	target.air_position=b.position+Vector3(0,0,100)
	Bomb.step(race.weapons,race,b,.01)
	check(b.target==-1,"Lost lock cannot reacquire or switch targets")
	race=setup();p=race.racers[0]
	var expected:=Bomb.preview(race,p)
	race.weapons.activate(race,0);b=race.weapons.bombs[0]
	for i in range(1000):
		if race.weapons.bombs.is_empty(): break
		Bomb.step(race.weapons,race,b,1./120.)
	check(not race.weapons.bursts.is_empty() and race.weapons.bursts[-1].position.distance_to(expected.position)<5.,"Unguided impact agrees with displayed prediction")
	race=setup();p=race.racers[0]
	race.weapons.begin_step(race,.01,[{},{}])
	check(p.bomb_armed and race.weapons.bombs.is_empty(),"Automatic preview never fires on its own")
	race.weapons.begin_step(race,.01,[{"fire":true},{}])
	check(race.weapons.bombs.size()==1 and p.weapon=="","Main weapon input fires on press")
	race=setup();p=race.racers[0];race.racers[1].weapon="bomb"
	race.weapons.begin_step(race,.01,[{},{}])
	check(not p.bomb_preview.is_empty() and not race.racers[1].bomb_preview.is_empty(),"Both split-screen players receive preview immediately")
	var previous_point:Vector3=p.bomb_preview.position
	p.air_frame=Basis(Vector3.UP,.3)*p.air_frame;p.air_velocity=Basis(Vector3.UP,.3)*p.air_velocity
	race.weapons.begin_step(race,.01,[{},{}])
	check(p.bomb_preview.position.distance_to(previous_point)>20.,"Aim moves on the very next tick without waiting for a clock deadline")
	p.bot=true;p.view=false
	Bomb.input_step(race.weapons,race,0,false,.01)
	check(p.bomb_preview.is_empty(),"Unseen AI never computes a HUD trajectory")
	# Acquisition must work in open air, independent of the eventual impact dot.
	race=setup();p=race.racers[0];target=race.racers[1]
	p.air_position=Vector3(0,4000,0);p.air_frame=Basis.IDENTITY;p.air_velocity=Vector3(0,0,240)
	target.air_position=p.air_position+Vector3(160,-70,400);target.air_velocity=Vector3(0,0,170)
	aim=Bomb.preview(race,p)
	check(aim.target==1 and not aim.landed,"Forward enemy locks even when no ground lies under the glide path")
	var lead_before:Vector3=aim.target_position
	Bomb.input_step(race.weapons,race,0,false,.01)
	target.air_position.x+=30.
	Bomb.input_step(race.weapons,race,0,false,.01)
	check(p.bomb_preview.target_position.distance_to(lead_before)>15.,"Moving enemy interception dot refreshes immediately")
	target.air_position=p.air_position+Vector3(0,0,1200)
	check(Bomb.preview(race,p).target==-1,"Enemies beyond seeker range do not lock")
	target.air_position=p.air_position-Vector3(0,0,200)
	check(Bomb.preview(race,p).target==-1,"Enemies behind do not lock")
	target.air_position=p.air_position+Vector3(0,0,400)
	race.track.obstacles.add_box(Transform3D(Basis.IDENTITY,p.air_position+Vector3(0,0,200)),AABB(Vector3(-30,-30,-5),Vector3(60,60,10)))
	check(Bomb.preview(race,p).target==-1,"Scenery blocks target acquisition")
	race.track.obstacles=Obstacles.new();target.warp_time=1.
	check(Bomb.preview(race,p).target==-1,"Warped rivals cannot be acquired")
	target.warp_time=0.;target.finished=true
	check(Bomb.preview(race,p).target==-1,"Finished rivals cannot be acquired")
	# Reproduce the original failure with the launcher moving alongside its bomb.
	for entry_speed in [120.,235.,330.,440.]:
		race=setup();p=race.racers[0]
		var direction:Vector3=p.air_velocity.normalized()
		p.air_velocity=direction*entry_speed;p.speed=entry_speed
		race.weapons.activate(race,0);b=race.weapons.bombs[0]
		var peak:float=b.velocity.length()
		for frame in range(600):
			if race.weapons.bombs.is_empty(): break
			# Match flight's decaying overspeed envelope after leaving the road.
			p.air_velocity=direction*minf(entry_speed,maxf(235.,entry_speed-70.*frame/120.))
			p.air_position+=p.air_velocity/120.
			Bomb.step(race.weapons,race,b,1./120.)
			peak=maxf(peak,b.velocity.length())
		check(peak<=Bomb.BOOST_SPEED+.01 and peak<race.Weapons.MISSILE_SPEED,"Rocket speed stays below cruise missile speed at every launch speed")
		check(not p.crashed and p.energy>75.,"Moving launcher avoids its own normal bomb release")
		print("GLIDE_CLEARANCE speed=",entry_speed," energy=",p.energy," separation=",b.position.distance_to(p.air_position))
	# A nearby hull must not arm merely because a fixed timer expired.
	race=setup();p=race.racers[0];race.weapons.activate(race,0);b=race.weapons.bombs[0]
	b.age=.9;p.air_position=b.position
	Bomb.step(race.weapons,race,b,.001)
	check(race.weapons.bombs.has(b) and not b.owner_clear,"Owner collision waits for actual clearance")
	p.air_position=b.position-Vector3(0,0,35);Bomb.step(race.weapons,race,b,.001)
	check(b.owner_clear,"Owner collision arms after physical separation")
	var coast:=Bomb.velocity_step(Vector3(0,0,350),Vector3.ZERO,Vector3.ZERO,false,.1,Bomb.BOOST_TIME+1.)
	check(coast.z<350.,"Motor stops and payload coasts after the short burn")
	var road_hits:=0
	for distance in [400.,900.,1500.,2200.,3100.,4000.]:
		race=setup();p=race.racers[0];target=race.racers[1]
		race.track.obstacles=null;race.track.hazards=null
		target.airborne=false;target.distance=distance;target.x=0.;target.speed=190.;target.heading=0.;target.startup=1.
		var n:Dictionary=race.track.sample(distance)
		target.ground_velocity=n.frame.z*target.speed
		p.air_position=Race.Track.point(n,55.,85.)-n.frame.z*210.
		p.air_frame=n.frame*Basis(Vector3.RIGHT,.18);p.air_velocity=p.air_frame.z*240.
		aim=Bomb.preview(race,p)
		check(aim.target==1,"On-road rival in a forward corner approach acquires at %s"%distance)
		race.weapons.activate(race,0);b=race.weapons.bombs[0]
		for frame in range(960):
			if race.weapons.bombs.is_empty(): break
			target.distance+=target.speed/120.
			target.ground_velocity=race.track.sample(target.distance).frame.z*target.speed
			Bomb.step(race.weapons,race,b,1./120.)
		if target.energy<50.: road_hits+=1
		print("GLIDE_ROAD distance=",distance," energy=",target.energy," age=",b.age)
	check(road_hits>=5,"Aimed releases reliably damage road rivals through ordinary corners")
	# The prediction broadphase must preserve road impacts across banks/loops.
	var compared:=0
	for distance in range(0,int(race.track.length),85):
		var n:Dictionary=race.track.sample(distance)
		var from:=Race.Track.point(n,0.,12.);var to:=Race.Track.point(n,0.,-12.)
		var full:=Bomb.contact(race.track,from,to,distance)
		var fast:=Bomb.contact(race.track,from,to,distance,true)
		if full.is_empty(): continue
		compared+=1
		check(not fast.is_empty(),"Fast prediction preserves swept deck collision at %s"%distance)
	check(compared>40,"Prediction broadphase exercised across the whole course")
	print("GLIDE_BOMB_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
