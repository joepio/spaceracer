extends RefCounted
## One vehicle-relative chase rig for road, takeoff, flight and landing.
static func update(camera:Camera3D,pose:Transform3D,speed:float,boosting:bool,dt:float,snap:bool=false,acceleration:float=0.,effects_enabled:bool=true)->void:
	var rush:=smoothstep(70.,390.,speed) if effects_enabled else 0.
	var boost_target:=smoothstep(180.,350.,speed) if boosting and effects_enabled else 0.
	var surge_target:=smoothstep(15.,180.,acceleration)*smoothstep(0.,90.,speed) if effects_enabled else 0.
	var boost:float=camera.get_meta("speed_boost",0.)
	var surge:float=camera.get_meta("speed_surge",0.)
	boost=boost_target if snap else lerpf(boost,boost_target,1.-exp(-dt*(10. if boost_target>boost else 3.)))
	surge=surge_target if snap else lerpf(surge,surge_target,1.-exp(-dt*(8. if surge_target>surge else 2.5)))
	camera.set_meta("speed_rush",rush)
	camera.set_meta("speed_boost",boost)
	camera.set_meta("speed_surge",surge)
	camera.set_meta("speed_velocity",speed)
	var wanted:=pose.basis.get_rotation_quaternion()
	var rotation:Quaternion=camera.get_meta("chase_rotation",wanted)
	# Smooth orientation/offsets, never world translation: at racing speed that
	# would add metres of lag and make the craft run away from its own camera.
	rotation=wanted if snap else rotation.slerp(wanted,1-exp(-dt*6.5)).normalized()
	camera.set_meta("chase_rotation",rotation)
	var frame:=Basis(rotation)
	var wanted_distance:=18+speed*.008+boost*1.3+surge*.6
	var distance:float=camera.get_meta("chase_distance",wanted_distance)
	distance=wanted_distance if snap else lerpf(distance,wanted_distance,1-exp(-dt*5))
	camera.set_meta("chase_distance",distance)
	camera.position=pose.origin-frame.z*distance+frame.y*7
	camera.look_at(pose.origin+frame.z*24+frame.y*1.5,frame.y)
	# Optical pull-back follows acceleration as well as speed, then settles as
	# thrust stops changing velocity. Boost opens the lens further, without cuts.
	var fov:=clampf(76+rush*16+surge*4.+boost*8.,76,103)
	camera.fov=fov if snap else lerpf(camera.fov,fov,1-exp(-dt*5))
	var clock:float=camera.get_meta("speed_clock",0.)
	if effects_enabled: clock+=minf(dt,.05)
	camera.set_meta("speed_clock",clock)
	# Small, deterministic vibration; never feed shake back into chase rotation.
	var shake:=boost*(.4+.6*rush) if effects_enabled and not snap else 0.
	camera.position+=frame.x*sin(clock*73.)*.035*shake+frame.y*sin(clock*91.)*.025*shake
	camera.rotate_object_local(Vector3.RIGHT,deg_to_rad(.16)*shake*(sin(clock*67.)+.3*sin(clock*109.)))
	camera.rotate_object_local(Vector3.UP,deg_to_rad(.12)*shake*sin(clock*83.))
	camera.rotate_object_local(Vector3.BACK,deg_to_rad(.08)*shake*sin(clock*57.))
