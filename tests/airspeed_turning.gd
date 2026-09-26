extends SceneTree
const Race=preload("res://src/race.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func flight(speed:float,pitch:float,throttle:float,seconds:float=1.)->Dictionary:
	var p:Dictionary=Race.new([{"slot":0}],31).racers[0]
	p.air_frame=Basis(Vector3.RIGHT,-deg_to_rad(pitch))
	p.air_velocity=Vector3(0,0,speed);p.air_entry_speed=speed
	for tick in range(int(seconds*120)):
		p.air_time+=1./120.
		Race.Flight.integrate_air(p,1./120.,0.,0.,throttle,0.)
	return p
func _initialize()->void:
	var slow:=flight(60.,0.,0.)
	var fast:=flight(235.,0.,1.)
	check(slow.air_position.y< -18. and slow.air_velocity.y< -35.,"Low airspeed produces an unmistakable gravity-driven fall")
	check(absf(fast.air_position.y)<2.,"Fast powered flight retains stable lift")
	var flat:=flight(130.,0.,1.)
	var raised:=flight(130.,22.,1.)
	var unpowered:=flight(130.,22.,0.)
	check(flat.air_position.y< -10. and raised.air_position.y>flat.air_position.y+10.,"A moderate nose-up attitude catches approach-speed sink")
	check(raised.air_position.y>unpowered.air_position.y+10. and raised.speed>unpowered.speed+20.,"Throttle matters for recovering slow flight")
	var stalled:=flight(60.,60.,1.)
	check(stalled.air_position.y< -4.,"Extreme nose-up input cannot make a slow craft hover")
	var coasting:=flight(235.,0.,0.,3.)
	check(coasting.air_position.y< -20. and coasting.air_velocity.y< -20.,"Releasing throttle eventually loses speed and lift")
	for direction in [-1.,1.]:
		var race:=Race.new([{"slot":0}],31)
		race.countdown=0.
		var p:Dictionary=race.racers[0]
		p.distance=200.;p.x=0.
		var rotation:=0.
		for tick in range(120*8):
			var before:float=p.heading
			race.step(1./120.,[{"steer":direction,"brake":1.}])
			rotation+=angle_difference(before,p.heading)
		check(rotation*direction>TAU*2.,"Stationary steering completes two full rotations in either direction")
		check(absf(p.distance-200.)<.01 and absf(p.x)<.01,"Turning on the spot does not translate the craft")
		var resting:float=p.heading
		for tick in range(120): race.step(1./120.,[{"brake":1.}])
		check(absf(angle_difference(resting,p.heading))<.001,"Releasing stationary steering holds the selected heading")
	var reverse:=Race.new([{"slot":0}],31)
	reverse.countdown=0.
	var driver:Dictionary=reverse.racers[0]
	driver.distance=200.;driver.x=0.;driver.heading=PI;driver.speed=10.
	for tick in range(42): reverse.step(1./120.,[{"throttle":1.}])
	check(driver.distance<196. and driver.lap==1,"Facing backwards drives backwards without awarding lap progress")
	var sideways:=Race.new([{"slot":0}],31)
	sideways.countdown=0.
	var side:Dictionary=sideways.racers[0]
	side.distance=200.;side.x=0.;side.heading=PI*.5;side.speed=60.
	for tick in range(12): sideways.step(1./120.,[{"throttle":1.}])
	check(absf(side.distance-200.)<1.5 and side.x>2.,"Sideways thrust follows the nose without artificial forward travel")
	var impact:=Race.new([{"slot":0},{"slot":1}],31)
	impact.racers[0].merge({"distance":200.,"x":0.,"heading":0.,"speed":100.},true)
	impact.racers[1].merge({"distance":207.,"x":0.,"heading":PI,"speed":100.},true)
	impact.resolve_contacts()
	check(impact.racers[0].speed<50. and impact.racers[1].speed<50.,"Head-on collision slows both oppositely facing craft")
	print("AIRSPEED_TURNING_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
