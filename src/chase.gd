extends RefCounted
## One vehicle-relative chase rig for road, takeoff, flight and landing.
static func fitted_fov(camera:Camera3D,reference:float)->float:
	# Preserve the 16:9 horizontal lens on wide split-screen/ultrawide surfaces.
	var dimensions:=camera.get_viewport().get_visible_rect().size
	var aspect:=dimensions.x/maxf(1.,dimensions.y)
	return rad_to_deg(2.*atan(tan(deg_to_rad(reference)*.5)*minf(1.,(16./9.)/aspect)))

static func update(camera:Camera3D,pose:Transform3D,speed:float,boosting:bool,dt:float,snap:bool=false,acceleration:float=0.,effects_enabled:bool=true)->void:
	var previous:=camera.position
	camera.set_meta("crash_serial",-1)
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
	var extreme:=smoothstep(390.,510.,speed) if effects_enabled else 0.
	var fov:=fitted_fov(camera,clampf(72+rush*10+surge*5.+boost*9.+extreme*4.,72,100))
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
	if dt>0.: camera.set_meta("chase_velocity",Vector3.ZERO if snap else (camera.position-previous)/dt)

static func update_respawn(camera:Camera3D,pose:Transform3D,serial:int,elapsed:float,duration:float,dt:float,snap:bool=false)->void:
	if int(camera.get_meta("crash_serial",-1))!=serial or snap:
		camera.set_meta("crash_serial",serial)
		camera.set_meta("respawn_from",camera.transform)
		camera.set_meta("respawn_velocity",Vector3(camera.get_meta("chase_velocity",Vector3.ZERO)).limit_length(120.))
		camera.set_meta("respawn_fov",camera.fov)
	if dt<=0. and not snap: return
	var start:Transform3D=camera.get_meta("respawn_from")
	var velocity:Vector3=camera.get_meta("respawn_velocity")
	var distance:=18.+90.*.008
	var destination:=pose.origin-pose.basis.z*distance+pose.basis.y*7.
	var end:=Transform3D(pose.basis,destination).looking_at(pose.origin+pose.basis.z*24.+pose.basis.y*1.5,pose.basis.y)
	var u:=clampf(elapsed/maxf(.01,duration-.12),0.,1.)
	var blend:=u*u*u*(u*(u*6.-15.)+10.)
	# A small elevated arc clears the road; inherited momentum dies away while
	# both ends of the transfer remain smooth. Never follow falling wreck pieces.
	var lift:=minf(55.,start.origin.distance_to(destination)*.12)
	var arc:=16.*u*u*(1.-u)*(1.-u)
	camera.position=start.origin.lerp(destination,blend)+velocity*duration*u*pow(1.-u,3.)+Vector3.UP*lift*arc
	camera.quaternion=start.basis.get_rotation_quaternion().slerp(end.basis.get_rotation_quaternion(),blend).normalized()
	camera.fov=lerpf(float(camera.get_meta("respawn_fov")),fitted_fov(camera,72.),blend)
	camera.set_meta("chase_rotation",pose.basis.get_rotation_quaternion())
	camera.set_meta("chase_distance",distance)
	camera.set_meta("chase_velocity",Vector3.ZERO)
	for key in ["speed_rush","speed_boost","speed_surge","speed_velocity"]: camera.set_meta(key,0.)

static func update_crash(camera:Camera3D,impact:Vector3,focus:Vector3,serial:int,dt:float,obstacles:RefCounted=null,snap:bool=false)->void:
	if int(camera.get_meta("crash_serial",-1))!=serial or snap:
		camera.set_meta("crash_serial",serial)
		camera.set_meta("crash_velocity",Vector3(camera.get_meta("chase_velocity",Vector3.ZERO)).limit_length(240.))
		camera.set_meta("crash_aim",camera.position-camera.basis.z*30.)
		camera.set_meta("crash_up",camera.basis.y)
		camera.set_meta("crash_anchor",impact)
	if dt<=0.: return
	var velocity:Vector3=camera.get_meta("crash_velocity")
	# Integrate exponential braking: continuous movement, bounded stopping distance.
	var decay:=exp(-dt*16.)
	var destination:=camera.position+velocity*(1.-decay)/16.
	# Rebounding debris can travel toward the chase rig. Ease back to keep the
	# breakup readable instead of coasting into the explosion or loose wings.
	var separation:=destination-focus
	if separation.length()<18. and separation.length()>.01:
		destination+=separation.normalized()*(18.-separation.length())*(1.-exp(-dt*8.))
	if obstacles!=null:
		var hit:Dictionary=obstacles.trace(camera.position,destination,.65)
		if not hit.is_empty(): destination=hit.position+hit.normal*.05;velocity=velocity.slide(hit.normal)
	camera.position=destination
	camera.set_meta("crash_velocity",velocity*decay)
	var aim:Vector3=camera.get_meta("crash_aim")
	var anchor:Vector3=camera.get_meta("crash_anchor")
	var target:=anchor+(focus-anchor).limit_length(45.)
	aim=aim.lerp(target,1.-exp(-dt*3.5))
	camera.set_meta("crash_aim",aim)
	if camera.position.distance_squared_to(aim)>.01:
		var desired:=camera.transform.looking_at(aim,camera.get_meta("crash_up"))
		camera.quaternion=camera.quaternion.slerp(desired.basis.get_rotation_quaternion(),1.-exp(-dt*7.)).normalized()
	camera.fov=lerpf(camera.fov,fitted_fov(camera,72.),1.-exp(-dt*1.8))
	for key in ["speed_rush","speed_boost","speed_surge","speed_velocity"]: camera.set_meta(key,0.)
