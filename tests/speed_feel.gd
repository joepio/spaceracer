extends SceneTree
const Chase=preload("res://src/chase.gd")
const SpeedEffects=preload("res://src/speed_effects.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var camera:=Camera3D.new()
	root.add_child(camera)
	var pose:=Transform3D.IDENTITY
	Chase.update(camera,pose,0.,false,0.,true)
	check(camera.fov==76. and float(camera.get_meta("speed_rush"))==0.,"No speed effects on a stationary craft")
	for tick in range(240): Chase.update(camera,pose,265.,false,1./120.)
	var cruise:=camera.fov
	check(cruise>85. and cruise<92.,"Cruise lens opens without maximum boost distortion")
	for tick in range(90): Chase.update(camera,pose,265.,false,1./120.,false,200.)
	check(camera.fov>cruise+2.5,"Actual acceleration opens the lens at the same speed")
	for tick in range(360): Chase.update(camera,pose,265.,false,1./120.)
	check(absf(camera.fov-cruise)<.1,"Acceleration surge settles at steady speed")
	for tick in range(300):
		Chase.update(camera,pose,390.,true,1./120.,false,0.)
		var unshaken:=Vector3(0.,7.,-float(camera.get_meta("chase_distance")))
		check(camera.position.distance_to(unshaken)<.05,"Boost vibration stays under five centimetres")
		check(camera.basis.determinant()>.999 and camera.fov<=103.,"Camera stays orthonormal with bounded lens widening")
	check(camera.fov>98.,"Full boost has a distinctly wider lens")
	check(camera.get_meta("chase_rotation")==Quaternion.IDENTITY,"Vibration never accumulates in the chase orientation")
	var before:=camera.transform
	Chase.update(camera,pose,390.,true,0.)
	check(camera.transform.is_equal_approx(before),"Zero elapsed time freezes boost vibration")
	var other:=Camera3D.new()
	root.add_child(other)
	Chase.update(other,pose,90.,false,0.,true)
	check(other.fov<camera.fov-15. and float(other.get_meta("speed_boost"))==0.,"Each split-screen camera has independent speed state")
	var particles:=SpeedEffects.new()
	root.add_child(particles)
	particles.update_effects(camera,.01,true)
	var travel:=particles.travel
	particles.update_effects(camera,0.,true)
	check(particles.travel==travel,"Whoosh particles use elapsed travel, not wall time")
	particles.update_effects(camera,.1,false)
	check(not particles.visible and particles.travel==travel,"Menu/pause/recovery suppress particles and freeze their travel")
	particles.update_effects(camera,.01,true,true)
	check(particles.count==14,"Performance mode uses a smaller fixed particle budget")
	Chase.update(camera,pose,390.,true,0.,true,200.,false)
	check(camera.fov==76. and float(camera.get_meta("speed_boost"))==0.,"Disabled effects cannot leak a boost surge into the menu")
	particles.free();camera.free();other.free()
	print("SPEED_FEEL_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
