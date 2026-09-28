extends SceneTree
const Race=preload("res://src/race.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var race:=Race.new([{"slot":0,"name":"Nova"},{"slot":1,"name":"Flux"},{"slot":2,"name":"Echo"}],31)
	race.countdown=0.
	var p:Dictionary=race.racers[0];var rival:Dictionary=race.racers[1]
	race.weapons.damage(race,rival,10.,1.,Vector3.ZERO,0)
	check(p.destruction_notices.is_empty(),"Nonlethal hits never claim destruction")
	race.weapons.damage(race,rival,100.,1.,Vector3.ZERO,0)
	check(rival.crashed and p.destruction_notices.size()==1 and p.destruction_notices[0].name=="Flux","Killer sees destroyed pilot name")
	check(rival.destruction_notices.is_empty() and race.racers[2].destruction_notices.is_empty(),"Notification stays on the attacker's split-screen view")
	race.weapons.damage(race,rival,100.,1.,Vector3.ZERO,0)
	check(p.destruction_notices.size()==1,"Already-destroyed hull cannot generate duplicate notices")
	race.weapons.damage(race,race.racers[2],100.,1.,Vector3.ZERO,0)
	check(p.destruction_notices.size()==2,"Multiple victims retain their own notice")
	race.weapons.begin_step(race,.49,[{},{},{}])
	check(p.destruction_notices.size()==2,"Confirmation lasts approximately half a second")
	race.weapons.begin_step(race,.02,[{},{},{}])
	check(p.destruction_notices.is_empty(),"Confirmation expires after 500 ms")
	race.weapons.damage(race,p,100.,1.,Vector3.ZERO,0)
	check(p.crashed and p.destruction_notices.is_empty(),"Self-destruction is not credited as an opponent kill")
	# Actual area damage: at 60 m a full-health craft should be nearly destroyed.
	race=Race.new([{"slot":0},{"slot":1},{"slot":2}],31);race.countdown=0.
	for i in range(3):
		var craft:Dictionary=race.racers[i]
		craft.airborne=true;craft.air_position=Vector3([200.,35.,60.][i],1000,0);craft.air_frame=Basis.IDENTITY
	var bomb:={"id":1,"owner":0,"owner_blast_clear":true}
	race.weapons.bombs.append(bomb)
	race.weapons.DiveBomb.detonate(race.weapons,race,bomb,Vector3(0,1000,0))
	check(race.racers[1].crashed,"Glide blast destroys a full-health rival within 35 metres")
	check(race.racers[2].energy<10. and not race.racers[2].crashed,"Glide blast does heavy damage 60 metres away")
	check(race.racers[0].destruction_notices.size()==1,"Actual glide detonation reports the destroyed rival")
	print("DESTRUCTION_CONFIRMATION_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
