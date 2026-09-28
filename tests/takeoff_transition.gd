extends SceneTree
const Race=preload("res://src/race.gd")
const Flight=preload("res://src/flight.gd")
var failures:=0
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	for hz in [60,120]:
		var race:=Race.new([{"slot":0}],31,3,"easy")
		race.countdown=0.
		var p:Dictionary=race.racers[0];p.speed=265.;p.distance=0.;p.startup=1.
		var elapsed:=0.
		for tick in range(hz*2):
			race.step(1./hz,[{"throttle":1.,"trim":-1.}]);elapsed+=1./hz
			if p.airborne: break
		print("TAKEOFF hz=",hz," seconds=",elapsed," height=",p.lift," rise=",p.lift_speed)
		check(p.airborne and elapsed>.25 and elapsed<.65,"Prompt takeoff with a readable rising phase")
		var velocity:Vector3=p.air_velocity
		var rotation:Basis=p.air_frame
		race.step(1./hz,[{"throttle":1.,"trim":-1.}])
		var acceleration:float=(p.air_velocity-velocity).length()*hz
		var angle:=rad_to_deg(rotation.get_rotation_quaternion().angle_to(p.air_frame.get_rotation_quaternion()))
		print("FIRST_AIR acceleration=",acceleration," angular_step_deg=",angle)
		check(acceleration<180.,"No sudden acceleration spike on first airborne frame")
		check(angle<.8,"No abrupt fighter pitch on the first frame")
		for tick in range(hz/2): race.step(1./hz,[{"throttle":1.,"trim":-.35}])
		check(p.airborne and not p.crashed,"Clean climb continues into controlled flight")
	print("TAKEOFF_TESTS failures=",failures);quit(1 if failures else 0)
