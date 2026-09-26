extends SceneTree
const Race=preload("res://src/race.gd")
const Flight=preload("res://src/flight.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func pilot()->Dictionary:
	var p:Dictionary=Race.new([{"slot":0}],31).racers[0]
	p.airborne=true;p.air_frame=Basis.IDENTITY;p.air_velocity=Vector3.BACK*235.;p.air_entry_speed=235.
	return p
func _initialize()->void: call_deferred("run")
func run()->void:
	for axis in ["pitch","yaw","banked_pitch"]:
		for hz in [30,60,120]:
			var p:=pilot()
			if axis=="banked_pitch": p.air_frame=Basis(Vector3.BACK,PI*.5)
			p.trim=-1. if axis!="yaw" else 0.
			for tick in range(hz):
				p.air_time+=1./hz
				Flight.integrate_air(p,1./hz,0.,1. if axis=="yaw" else 0.,1.,0.)
			var lag:=rad_to_deg(p.air_frame.z.angle_to(p.air_velocity))
			var turn:=rad_to_deg(Vector3.BACK.angle_to(p.air_velocity))
			print("JET_TURN axis=%s hz=%d lag_deg=%.2f path_turn_deg=%.2f speed=%.2f"%[axis,hz,lag,turn,p.speed])
			check(lag<12.,"Fast %s flight path follows the nose, hz=%d"%[axis,hz])
			check(turn>70.,"Full %s redirects travel decisively within one second, hz=%d"%[axis,hz])
			check(p.speed>150. and p.speed<=235.01,"Hard turn retains useful speed below driving cruise")
			p.trim=0.
			var before:Vector3=p.air_velocity.normalized()
			for tick in range(hz/4):
				p.air_time+=1./hz;Flight.integrate_air(p,1./hz,0.,0.,1.,0.)
			check(rad_to_deg(before.angle_to(p.air_velocity))<15.,"Releasing controls arrests the turn quickly")
	var slow:=pilot();slow.air_velocity=Vector3.BACK*60.;slow.trim=-1.
	for tick in range(120): Flight.integrate_air(slow,1./120.,0.,0.,0.,0.)
	check(slow.air_position.y< -15. and slow.air_velocity.y< -25.,"Low-speed nose-up input cannot redirect gravity into free climbing")
	print("JET_TURN_TESTS %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
