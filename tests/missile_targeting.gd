extends SceneTree
const Race=preload("res://src/race.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func fresh()->RefCounted:
	var race:=Race.new([{"slot":0},{"slot":1},{"slot":2}],31)
	race.countdown=0.;race.clock=5.
	race.checkpoints.gates.clear()
	for i in range(3): race.racers[i].distance=4000.-i*800.;race.racers[i].speed=200.
	race.racers[2].weapon="missile";race.weapons.activate(race,2)
	return race
func _initialize()->void: call_deferred("run")
func run()->void:
	var race:=fresh();var m:Dictionary=race.weapons.missiles[0]
	race.racers[1].distance=4300.
	race.weapons.step_missile(race,m,.01)
	check(m.target==1 and not m.locked,"Cruise updates to new race leader before warning")
	m.distance=4200.;m.age=2.;m.position=Race.Track.point(race.track.sample(m.distance),0.,10.)
	race.weapons.step_missile(race,m,.01)
	check(m.locked and race.Weapons.laser_strength(race,m)>0.,"Laser window locks target")
	race.racers[0].distance=4400.;race.weapons.step_missile(race,m,.01)
	check(m.target==1,"Overtake during visible laser cannot redirect missile")
	race=fresh();race.weapons.missiles.clear();race.racers[0].finished=true;race.racers[0].time=5.;race.racers[2].weapon="missile"
	check(race.weapons.activate(race,2) and race.weapons.missiles[0].target==1,"Finished P1 does not prevent launch at remaining leader")
	race=fresh();m=race.weapons.missiles[0];race.racers[0].finished=true
	race.weapons.step_missile(race,m,.01)
	check(m.target==1 and race.weapons.missiles.has(m),"Uncommitted cruise skips newly finished target")
	m.locked=true;race.racers[1].finished=true;race.weapons.step_missile(race,m,.01)
	check(m.target==1 and m.evaded,"Committed missile dissipates when victim finishes, without redirecting")
	race=fresh();race.weapons.missiles.clear();race.racers[0].weapon="missile"
	check(race.weapons.activate(race,0) and race.weapons.missiles[0].target==1,"Carried missile stays usable after owner takes lead")
	race=fresh();race.weapons.missiles.clear();race.racers[0].warp_time=2.;race.racers[2].weapon="missile"
	check(race.weapons.activate(race,2),"Target's temporary warp does not silently block launch")
	race=fresh();race.weapons.missiles.clear();race.racers[0].finished=true;race.racers[1].crashed=true;race.racers[2].weapon="missile"
	check(race.weapons.activate(race,2) and race.racers[2].weapon=="","No valid rivals still launches and consumes missile")
	m=race.weapons.missiles[0]
	check(m.target==-1 and m.unguided and is_inf(race.Weapons.missile_eta(race,m)) and race.Weapons.laser_strength(race,m)==0.,"Untargeted launch has no warning or laser")
	var origin:Vector3=m.position
	# A later respawn must not unexpectedly convert the free launch to homing.
	race.racers[1].crashed=false
	for i in range(90): race.weapons.step_missile(race,m,1./60.)
	check(m.target==-1 and m.position.distance_to(origin)>300. and m.launch_speed==race.Weapons.MISSILE_SPEED,"Untargeted missile accelerates away without acquiring a new victim")
	for i in range(300):
		if not race.weapons.missiles.has(m): break
		race.weapons.step_missile(race,m,1./60.)
	check(race.weapons.missiles.is_empty() and race.weapons.bursts.size()==1,"Untargeted missile eventually detonates exactly once")
	check(race.weapons.bursts[0].position.distance_to(origin)>900.,"Free launch explodes away from its rack")
	# EMP takes precedence over the unguided self-destruct fuse.
	race=fresh();race.weapons.missiles.clear();race.racers[0].finished=true;race.racers[1].finished=true;race.racers[2].weapon="missile"
	race.weapons.activate(race,2);m=race.weapons.missiles[0];m.disabled=true;m.evaded=true;m.fade=.2
	for i in range(20):
		if not race.weapons.missiles.has(m): break
		race.weapons.step_missile(race,m,.1)
	check(race.weapons.missiles.is_empty() and race.weapons.bursts.is_empty(),"Disabled free launch expires without exploding")
	print("MISSILE_TARGETING_TESTS failures=",failures);quit(1 if failures else 0)
