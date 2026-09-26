extends SceneTree
const Race=preload("res://src/race.gd")
const Weapons=preload("res://src/weapons.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func fresh()->RefCounted:
	var race:=Race.new([{"slot":2},{"slot":7},{"slot":11},{"slot":13}],31,3,"hard","forest")
	race.countdown=0.;race.clock=5.
	for i in range(4):
		var p:Dictionary=race.racers[i]
		p.airborne=true;p.air_time=.5;p.air_frame=Basis.IDENTITY
		p.air_position=Vector3(0,30,[0.,40.,180.,-40.][i]);p.distance=500.
	race.racers[0].weapon="jammer"
	return race
func _initialize()->void: call_deferred("run")
func run()->void:
	var frame:=Transform3D.IDENTITY
	check(Weapons.jammer_strength(frame,Vector3(0,0,25))>.95,"Close centred rival gets strong interference")
	check(Weapons.jammer_strength(frame,Vector3(0,0,220))<.1,"Interference fades at long range")
	check(Weapons.jammer_strength(frame,Vector3(0,0,-25))==0.,"Behind the dish is outside its cone")
	check(Weapons.jammer_strength(frame,Vector3(120,0,100))==0.,"Rival beside the cone is unaffected")
	check(Weapons.jammer_strength(frame,Vector3(0,120,100))==0.,"Cone has vertical as well as horizontal bounds")
	check(Weapons.jammer_strength(frame,Vector3(0,0,270))==0.,"Range is bounded")
	var turned:=Transform3D(Basis(Vector3.UP,PI*.5),Vector3(50,10,90))
	check(Weapons.jammer_strength(turned,turned*Vector3(0,0,40))>.9,"Cone follows craft yaw/pitch/roll in world space")
	var race:=fresh();var owner:Dictionary=race.racers[0];var close:Dictionary=race.racers[1]
	check(race.weapons.activate(race,0) and owner.weapon.is_empty() and owner.jammer_time==6.,"Activation deploys a temporary jammer and consumes inventory")
	race.weapons.begin_step(race,.01,[{},{},{},{}])
	check(owner.jam_strength==0. and race.racers[3].jam_strength==0.,"Emitter and trailing rival are exempt from this cone")
	check(close.jam_strength>race.racers[2].jam_strength and race.racers[2].jam_strength>0.,"Distance determines received strength")
	check(owner.jammer_deploy>0.,"Dish extends when the jammer is active")
	var original:Array=[{}, {"throttle":1.,"brake":.3,"fire":false,"reset":true,"boost":true},{},{}]
	var input:Array=race.weapons.jam_inputs(race,original)
	check(not original[1].has("steer"),"Controller input frames are not mutated")
	check(input[1].throttle==1. and input[1].brake==.3 and input[1].reset and input[1].boost and not input[1].fire,"Jammer never fabricates buttons, throttle or brake input")
	check(input[0]==original[0] and input[3]==original[3],"Unaffected players retain exact controls")
	check(input==race.weapons.jam_inputs(race,original),"Noise is reproducible at the same simulation time")
	var initial:float=input[1].steer
	race.clock+=.5;input=race.weapons.jam_inputs(race,original)
	check(not is_equal_approx(initial,input[1].steer),"Interference varies over time")
	var bounded:=true;var both_signs:=Vector2.ZERO
	for i in range(500):
		race.clock=i*.03;input=race.weapons.jam_inputs(race,original)
		bounded=bounded and absf(input[1].steer)<=.38 and absf(input[1].strafe)<=.32 and absf(input[1].trim)<=.18
		both_signs.x=minf(both_signs.x,input[1].steer);both_signs.y=maxf(both_signs.y,input[1].steer)
	check(bounded and both_signs.x<-.2 and both_signs.y>.2,"Disturbance is bounded and pulls in both directions")
	close.air_position=Vector3(150,30,40);race.weapons.step_jammers(race)
	check(close.jam_strength==0.,"Escaping sideways clears interference immediately")
	close.air_position=Vector3(0,30,40);owner.emp_time=1.;race.weapons.step_jammers(race)
	check(close.jam_strength==0.,"EMP temporarily silences the transmitter")
	owner.emp_time=0.;close.weapon_guard=1.;race.weapons.step_jammers(race)
	check(close.jam_strength==0.,"Fresh respawn protection works")
	close.weapon_guard=0.;close.warp_time=1.;race.weapons.step_jammers(race)
	check(close.jam_strength==0.,"Warp autopilot is not disrupted")
	close.warp_time=0.;race.racers[3].air_position=Vector3(0,30,-10);race.racers[3].jammer_time=4.
	race.weapons.step_jammers(race)
	check(close.jam_strength<=1.,"Multiple jammers cannot stack beyond full strength")
	race=fresh();race.weapons.activate(race,0)
	for i in range(630): race.weapons.begin_step(race,.01,[{},{},{},{}])
	check(race.racers[0].jammer_time==0. and race.racers[0].jammer_deploy==0. and race.racers[1].jam_strength==0.,"Timer expiry retracts dish and releases controls")
	race=fresh();race.weapons.activate(race,0);race.racers[0].crashed=true
	race.weapons.begin_step(race,.01,[{},{},{},{}])
	check(race.racers[0].jammer_time==0. and race.racers[1].jam_strength==0.,"A crashed emitter stops jamming")
	race=Race.new([{"slot":2},{"slot":7}],31,3,"hard","forest")
	race.countdown=0.;race.clock=5.
	race.racers[0].distance=500.;race.racers[1].distance=540.
	for p in race.racers: p.x=0.;p.speed=200.;p.startup=1.
	race.racers[0].weapon="jammer"
	race.step(.01,[{"fire":true,"throttle":1.},{"throttle":1.}])
	check(race.racers[1].jam_strength>.8 and absf(race.racers[1].input_steer)>.001,"Real race movement receives interference from a fresh X activation")
	check(race.racers[0].input_steer==0. and race.racers[1].input_throttle==1.,"Actual driving leaves emitter steering and victim throttle intact")
	var rolls:=0
	for i in range(6000):
		if race.weapons.choose(3,6)=="jammer": rolls+=1
	check(rolls>680 and rolls<1000,"Jammer is available in normal pickup rolls")
	print("JAMMER_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
