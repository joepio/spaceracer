extends RefCounted
## Non-competitive victory lap: a route-following pilot and broadcast camera.
const Track=preload("res://src/track.gd")
const Flight=preload("res://src/flight.gd")

static func step(p:Dictionary,track:RefCounted,dt:float,clock:float)->void:
	var n:Dictionary=track.sample(p.distance)
	if not p.has("victory_pose"):
		p.victory_pose=Flight.pose(p,n,clock)
		p.victory_age=0.
		p.victory_offset=p.victory_pose.origin-Track.point(n,p.x,Flight.HOVER)
		p.victory_rotation=n.frame.inverse()*p.victory_pose.basis
		p.weapon="";p.warp_time=0.;p.warp_fx=0.;p.boost=0.;p.on_pad=false
		p.drone_time=0.;p.jammer_time=0.;p.emp_time=0.;p.jam_strength=0.
		p.airborne=false;p.crashed=false;p.recovery=0.;p.flash=0.
		p.bump_time=0.;p.jammer_deploy=0.;p.drone_target=-1
	var age:float=p.victory_age+dt
	p.victory_age=age
	# Ease down from racing speed; anticipate bends instead of braking abruptly.
	var ahead:Dictionary=track.sample(p.distance+110.)
	var target_speed:=clampf(1.3/maxf(.005,absf(ahead.curve)),140.,225.)
	var previous_speed:float=p.speed
	p.speed=move_toward(p.speed,target_speed,dt*45.)
	p.acceleration=(p.speed-previous_speed)/maxf(dt,.00001)
	p.distance+=p.speed*dt
	n=track.sample(p.distance)
	var gap:float=n.get("split_gap",0.)
	var route:float=p.get("route",0.)
	if route==0.: route=1. if p.slot%2==0 else -1.
	var target_x:float=route*(gap+(n.width-gap)*.5) if gap>.01 else 0.
	p.x=lerpf(p.x,target_x,1.-exp(-dt*2.5))
	if gap>.01: p.x=route*maxf(absf(p.x),gap+5.)
	p.heading=lerp_angle(p.heading,0.,1.-exp(-dt*3.))
	p.trim=0.;p.slip=0.;p.slide=0.;p.braking=0.;p.brake_vfx=0.;p.unload=0.
	p.thrust=.72;p.input_throttle=.72;p.engine_power=lerpf(p.engine_power,.72,1.-exp(-dt*4.))
	p.input_steer=clampf(n.curve*p.speed*.5,-1.,1.)
	p.input_strafe=0.;p.input_pitch=0.;p.input_brake=0.
	# Cruise over mandatory gaps on their displaced route, with a smooth arc.
	var height:=Flight.HOVER
	var jump:Dictionary=track.jump_at(p.distance)
	if not jump.is_empty():
		var t:=clampf((fposmod(p.distance,track.length)-jump.takeoff)/(jump.landing-jump.takeoff),0.,1.)
		height+=sin(t*PI)*sin(t*PI)*18.
	var frame:Basis=Track.surface_frame(n,p.x)
	var rotation:Basis=p.victory_rotation
	frame=frame*rotation.slerp(Basis.IDENTITY,smoothstep(0.,1.3,age))
	p.victory_pose=Transform3D(frame,Track.point(n,p.x,height)+Vector3(p.victory_offset)*exp(-age*4.))

static func camera_update(camera:Camera3D,pose:Transform3D,n:Dictionary,age:float,obstacles:RefCounted,snap:bool=false)->void:
	if not camera.has_meta("victory_entry"):
		camera.set_meta("victory_entry",pose.affine_inverse()*camera.transform)
		camera.set_meta("victory_fov",camera.fov)
	var shot:=int(age/4.8)%4
	var t:=fmod(age,4.8)/4.8
	var offset:Vector3
	var fov:float
	match shot:
		0: offset=Vector3(lerpf(-13.,-9.,t),6.,-21.);fov=58.
		1: offset=Vector3(11.,4.5,lerpf(21.,16.,t));fov=52.
		2: offset=Vector3(lerpf(20.,16.,t),9.,-5.);fov=56.
		_: offset=Vector3(-7.,lerpf(25.,19.,t),-23.);fov=62.
	# Stay inside enclosing architecture and above the road in banked sections.
	if n.get("tunnel",false) or n.get("feature","")=="tube":
		offset.x=clampf(offset.x,-7.,7.);offset.y=minf(offset.y,7.)
	offset.x=clampf(offset.x,-n.width*.65,n.width*.65)
	var target:=pose.origin+pose.basis.y*1.
	var position:=pose*offset
	if obstacles!=null:
		var hit:Dictionary=obstacles.trace(target,position,.6)
		if not hit.is_empty(): position=hit.position+hit.normal*.7
	var desired:=Transform3D(pose.basis,position).looking_at(target,pose.basis.y)
	if age<1.3 and not snap:
		var entry:Transform3D=pose*Transform3D(camera.get_meta("victory_entry"))
		desired=entry.interpolate_with(desired,smoothstep(0.,1.3,age))
		fov=lerpf(float(camera.get_meta("victory_fov")),fov,smoothstep(0.,1.3,age))
	camera.transform=desired
	camera.fov=fov
	camera.set_meta("victory_shot",shot)
	for key in ["speed_rush","speed_boost","speed_surge","speed_velocity"]: camera.set_meta(key,0.)
