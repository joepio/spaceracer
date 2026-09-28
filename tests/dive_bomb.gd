extends SceneTree
const Race=preload("res://src/race.gd")
const Bomb=preload("res://src/dive_bomb.gd")
const Track=preload("res://src/track.gd")
const Obstacles=preload("res://src/obstacles.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var race:=Race.new([{"slot":0},{"slot":1},{"slot":2}],31,3,"hard","city")
	race.countdown=0.
	var p:Dictionary=race.racers[0];p.weapon="bomb";p.distance=400.
	check(not race.weapons.activate(race,0) and p.weapon=="bomb","Ground activation keeps the payload")
	var n:Dictionary=race.track.sample(p.distance)
	p.airborne=true;p.air_frame=n.frame;p.air_position=Track.point(n,0.,200.);p.air_velocity=n.frame.z*230.
	check(race.weapons.activate(race,0) and p.weapon=="" and race.weapons.bombs.size()==1,"Airborne release")
	var b:Dictionary=race.weapons.bombs[0]
	var velocity:Vector3=b.velocity;var origin:Vector3=b.position
	Bomb.step(race.weapons,race,b,.1)
	check(b.velocity.length()>velocity.length() and b.velocity.length()<=Bomb.BOOST_SPEED,"Brief rocket motor accelerates below cruise missile speed")
	check(b.position.distance_to(origin)>27. and b.position.distance_to(origin)<33.,"Launch boost moves the payload ahead")
	p.weapon="bomb"
	check(not race.weapons.activate(race,0) and p.weapon=="bomb","Only one live payload per owner")
	var hit:=Bomb.contact(race.track,Track.point(n,0.,20.),Track.point(n,0.,-20.),p.distance)
	check(not hit.is_empty(),"Fast swept drop hits road")
	check(Bomb.contact(race.track,Track.point(n,n.width+20.,20.),Track.point(n,n.width+20.,-20.),p.distance).is_empty(),"No invisible road outside deck")
	for jump in race.track.jumps:
		var gap:Dictionary=race.track.sample((jump.takeoff+jump.landing)*.5)
		if not gap.air_gap: continue
		check(Bomb.contact(race.track,Track.point(gap,0.,20.),Track.point(gap,0.,-20.),(jump.takeoff+jump.landing)*.5).is_empty(),"Jump gap does not detonate bomb")
	var wall:=Obstacles.new();race.track.obstacles=wall
	wall.add_box(Transform3D(Basis.IDENTITY.scaled(Vector3(30,40,2)),Vector3(0,600,0)))
	check(not Bomb.contact(race.track,Vector3(0,600,-200),Vector3(0,600,200),400.).is_empty(),"Swept bomb hits thin scenery at high speed")
	race.track.obstacles=null
	var center:=Vector3(0,700,0)
	for i in range(3):
		var racer:Dictionary=race.racers[i]
		racer.airborne=true;racer.air_frame=Basis.IDENTITY;racer.air_position=center+Vector3(0,0,[130.,2.,60.][i]);racer.energy=100.;racer.recovery=0.;racer.weapon_guard=0.
	Bomb.detonate(race.weapons,race,b,center)
	check(race.racers[1].crashed,"Near direct hit destroys full-energy plane")
	check(not race.racers[2].crashed and race.racers[2].energy<60.,"Outer blast has meaningful damage with falloff")
	check(p.energy==100.,"Escaping radius avoids damage")
	check(race.weapons.bombs.is_empty() and race.weapons.bursts[-1].size==45.,"Detonation consumes payload and creates giant blast")
	var energy:float=race.racers[2].energy
	Bomb.detonate(race.weapons,race,b,center)
	check(race.racers[2].energy==energy,"Cannot double detonate")
	var count:=0
	for i in range(10000):
		if race.weapons.choose(6,6,1800.)=="bomb": count+=1
	check(count>400 and count<850,"Rare pickup is available to trailing racers")
	# Blast risk includes the launching pilot.
	p.energy=100.;p.air_position=center;p.crashed=false;p.weapon_guard=0.;p.recovery=0.
	b.owner_blast_clear=true
	race.weapons.bombs.append(b);Bomb.detonate(race.weapons,race,b,center)
	check(p.crashed,"Pilot must escape their own blast")
	print("DIVE_BOMB_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
