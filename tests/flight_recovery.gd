extends SceneTree
const Race=preload("res://src/race.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func simulate(entry:float,pitch:float,throttle:float,hz:int,emp:bool=false,seconds:float=3.)->Dictionary:
	var p:Dictionary=Race.new([{"slot":0}],31).racers[0]
	p.air_frame=Basis(Vector3.RIGHT,-deg_to_rad(pitch));p.air_velocity=Vector3(0,-25,entry);p.air_entry_speed=entry
	p.emp_time=1. if emp else 0.
	var lowest:=0.;var peak:=0.
	for tick in range(int(seconds*hz)):
		p.air_time+=1./hz;Race.Flight.integrate_air(p,1./hz,0.,0.,throttle,0.)
		lowest=minf(lowest,p.air_position.y);peak=maxf(peak,p.speed)
	return {"forward":p.air_velocity.dot(p.air_frame.z),"vertical":p.air_velocity.y,"height":p.air_position.y,"lowest":lowest,"peak":peak,"velocity":p.air_velocity}
func _initialize()->void:
	for hz in [30,60,120]:
		for entry in [20.,60.,120.]:
			var flat:=simulate(entry,0.,1.,hz)
			var raised:=simulate(entry,15.,1.,hz)
			check(flat.forward>195.,"Full throttle restores forward speed even without pitching up")
			check(raised.forward>180. and raised.vertical>25.,"Modest nose-up throttle recovers sinking slow flight")
			check(raised.lowest> -38.,"Recovery does not require hundreds of metres of lost altitude")
			check(flat.peak<=Race.Flight.AIR_SPEED+.01 and raised.peak<=Race.Flight.AIR_SPEED+.01,"Recovery cannot bypass the lower flight speed cap")
			print("FLIGHT_RECOVERY hz=",hz," entry=",entry," forward=",raised.forward," climb=",raised.vertical," lost=",-raised.lowest)
	var off:=simulate(60.,15.,0.,120)
	var emp:=simulate(60.,15.,1.,120,true)
	check(off.vertical< -45. and off.height< -100.,"No throttle still loses lift and falls")
	check(off.velocity.distance_to(emp.velocity)<.001,"EMP disables recovery thrust")
	var long_flight:=simulate(20.,0.,1.,120,false,12.)
	check(long_flight.forward>210. and long_flight.peak<=Race.Flight.AIR_SPEED+.01,"Sustained throttle settles below road cruise speed")
	check(Race.Flight.AIR_SPEED<Race.TOP_SPEED,"Air cap remains below road cruise")
	print("FLIGHT_RECOVERY_TESTS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
