extends SceneTree
const Race=preload("res://src/race.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var roster:Array=[]
	for slot in range(8): roster.append({"slot":slot})
	var race:=Race.new(roster,35,3,"hard")
	race.countdown=0.
	for p in race.racers:
		p.distance=350.;p.x=0.;p.speed=240.
	var direct:Dictionary=race.racers[0]
	var frame:=Race.Weapons.pose(race,direct)
	race.racers[1].x=-12.;race.racers[2].x=20.
	for i in [3,4]:
		race.racers[i].airborne=true;race.racers[i].air_frame=frame.basis
		race.racers[i].air_position=frame.origin+frame.basis.y*(45. if i==3 else 12.)+frame.basis.x*7.
		race.racers[i].air_velocity=frame.basis.z*240.
	race.racers[6].weapon_guard=1.;race.racers[7].warp_time=1.
	var missile:Dictionary={"id":901,"owner":5,"target":0,"disabled":false}
	race.weapons.missiles.append(missile)
	race.weapons.detonate_missile(race,missile,frame.origin,frame.origin-frame.basis.z*10.)
	check(direct.energy==62.,"Direct hit applies full damage exactly once")
	check(race.racers[1].energy>direct.energy and race.racers[1].energy<race.racers[2].energy and race.racers[2].energy<100.,"Splash is weaker than direct hit and decreases with distance")
	check(race.racers[1].slip<0. and race.racers[2].slip>0.,"Blast throws opponents on opposite sides outward")
	check(direct.slide>.8 and race.racers[1].slide>race.racers[2].slide and race.racers[2].slide>0.,"Grip loss falls off with blast distance")
	check(race.racers[3].energy==100.,"World-space vertical distance excludes distant aircraft")
	var air_offset:Vector3=race.racers[4].air_position-frame.origin
	check(race.racers[4].energy<100. and race.racers[4].air_velocity.dot(air_offset.normalized())>20.,"Nearby airborne rivals receive radial impulse and damage")
	for i in [5,6,7]: check(race.racers[i].energy==100. and race.racers[i].slip==0. and race.racers[i].slide==0.,"Owner, recovery protection and warp immunity also prevent blast impulse")
	check(race.weapons.missiles.is_empty() and race.weapons.bursts.size()==1,"One detonation consumes one missile and emits one explosion")
	race.weapons.detonate_missile(race,missile,frame.origin,frame.origin-frame.basis.z*10.)
	check(direct.energy==62. and race.weapons.bursts.size()==1,"Repeated detonation cannot duplicate damage")
	# Run actual vehicle physics to catch impulses that disappear on the next tick.
	var kicked:=Race.new([{"slot":0}],35,3,"hard")
	var control:=Race.new([{"slot":0}],35,3,"hard")
	kicked.countdown=0.;control.countdown=0.
	kicked.racers[0]=direct.duplicate(true);control.racers[0]=direct.duplicate(true)
	control.racers[0].slip=0.;control.racers[0].slide=0.;control.racers[0].slide_hold=0.
	for tick in range(24):
		kicked.step(1./120.,[{"throttle":1.}]);control.step(1./120.,[{"throttle":1.}])
	check(absf(kicked.racers[0].x-control.racers[0].x)>4.,"Blast produces visible lateral displacement under normal physics")
	check(kicked.racers[0].slide>.7,"Grip loss persists beyond the impact frame")
	missile.disabled=true;race.weapons.missiles.append(missile)
	race.weapons.detonate_missile(race,missile,frame.origin,frame.origin)
	check(race.weapons.bursts.size()==1,"EMP-disabled missiles cannot create blast damage")
	print("MISSILE_BLAST_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
