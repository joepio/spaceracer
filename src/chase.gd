extends RefCounted
## One vehicle-relative chase rig for road, takeoff, flight and landing.
static func update(camera:Camera3D,pose:Transform3D,speed:float,boosting:bool,dt:float,snap:bool=false)->void:
	var wanted:=pose.basis.get_rotation_quaternion()
	var rotation:Quaternion=camera.get_meta("chase_rotation",wanted)
	# Smooth orientation/offsets, never world translation: at racing speed that
	# would add metres of lag and make the craft run away from its own camera.
	rotation=wanted if snap else rotation.slerp(wanted,1-exp(-dt*6.5)).normalized()
	camera.set_meta("chase_rotation",rotation)
	var frame:=Basis(rotation)
	var distance:float=camera.get_meta("chase_distance",18+speed*.008)
	distance=18+speed*.008 if snap else lerpf(distance,18+speed*.008,1-exp(-dt*5))
	camera.set_meta("chase_distance",distance)
	camera.position=pose.origin-frame.z*distance+frame.y*7
	camera.look_at(pose.origin+frame.z*24+frame.y*1.5,frame.y)
	var fov:=clampf(76+speed/32+(5 if boosting else 0),76,94)
	camera.fov=fov if snap else lerpf(camera.fov,fov,1-exp(-dt*5))
