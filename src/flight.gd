extends RefCounted
## World-space arcade flight. No road force or track-frame following after launch.
const HOVER:=1.3

static func ground_basis(frame:Basis,heading:float,trim:float,slip:float)->Basis:
	# The mesh nose is +Z: negative X rotation raises it. Back-stick trim is negative.
	return frame*Basis(Vector3.UP,-heading)*Basis(Vector3.FORWARD,slip*.004)*Basis(Vector3.RIGHT,trim*(.32 if trim<0 else .16))

static func hover_height(trim:float)->float:
	return HOVER+maxf(0,-trim)*.45

static func ground_pose(p:Dictionary,n:Dictionary,clock:float)->Transform3D:
	var frame:=ground_basis(n.frame,p.heading,p.trim,p.slip)
	# Small physical warning: the suspension extends and the wings gently buffet.
	var buffet:float=p.unload*.018*sin(clock*19+p.slot)
	frame=frame*Basis(Vector3.RIGHT,-p.unload*.08)*Basis(Vector3.BACK,buffet)
	if p.landing_blend>0:
		frame=frame.slerp(p.landing_frame,p.landing_blend).orthonormalized()
	return Transform3D(frame,n.p-n.frame.x*p.x+n.frame.y*(hover_height(p.trim)+p.lift))

static func pose(p:Dictionary,n:Dictionary,clock:float)->Transform3D:
	if p.airborne or (p.crashed and p.recovery>0):
		return Transform3D(p.air_frame,p.air_position)
	return ground_pose(p,n,clock)

static func unload(p:Dictionary,dt:float,crest_force:float,hold_force:float)->bool:
	var loose:float=maxf(0,-p.trim)
	var available:bool=p.launch_cooldown==0 and p.braking<.1 and p.speed>165
	var demand:float=smoothstep(.55,1.0,loose)*smoothstep(120,220,p.speed)
	if loose>.35 and p.speed>260:
		demand=maxf(demand,clampf((crest_force-hold_force)/180,0,1))
	if not available: demand=0.0
	p.unload=lerpf(p.unload,demand,1-exp(-dt*4))
	var target:float=4.5*p.unload*p.unload
	# A damped hover spring provides visible rising motion before release.
	p.lift_speed+=((target-p.lift)*32-p.lift_speed*9)*dt
	p.lift=maxf(0,p.lift+p.lift_speed*dt)
	if p.lift==0: p.lift_speed=maxf(0,p.lift_speed)
	return available and p.unload>.82 and p.lift>2.6 and p.lift_speed>0

static func launch(p:Dictionary,n:Dictionary,clock:float=0.0)->void:
	var transform:=ground_pose(p,n,clock)
	p.airborne=true
	p.air_time=0.0
	p.air_travel=0.0
	p.air_roll=0.0
	p.air_frame=transform.basis.orthonormalized()
	p.air_position=transform.origin
	# Carry the measured surface velocity and angular rate through release.
	# No position step, launch impulse or instantaneous turn of the flight path.
	p.air_velocity=p.ground_velocity
	p.on_pad=false
	p.slide=0.0
	p.drifting=false

static func integrate_air(p:Dictionary,dt:float,roll_input:float,yaw_input:float,throttle:float,brake:float)->void:
	var frame:Basis=p.air_frame
	var velocity:Vector3=p.air_velocity
	var speed:=velocity.length()
	var authority:=lerpf(.25,1.0,smoothstep(65,200,speed))
	# Body-axis rate controls: releasing the stick arrests rotation, not bank.
	# +Z is the nose, -X is pilot-right; back stick gives negative X pitch.
	var desired:=Vector3(p.trim*1.15,-yaw_input*.85,roll_input*2.6)*authority
	p.air_rates=p.air_rates.lerp(desired,1-exp(-dt*9))
	var rotation:Vector3=p.air_rates*dt
	if rotation.length_squared()>.000000001:
		frame=(frame*Basis(Quaternion(rotation.normalized(),rotation.length()))).orthonormalized()
	p.air_frame=frame
	p.air_roll+=p.air_rates.z*dt
	var airflow:=velocity.normalized() if speed>1 else frame.z
	var alignment:=maxf(0,frame.z.dot(airflow))
	var attack:=atan2(-velocity.dot(frame.y),maxf(1,velocity.dot(frame.z)))
	var wing_lift:=frame.y-airflow*frame.y.dot(airflow)
	if wing_lift.length_squared()>.001: wing_lift=wing_lift.normalized()
	var stall:=1-smoothstep(.48,1.05,absf(attack))
	var coefficient:=clampf(.8+attack*7,-2.0,4.0)*stall
	var lift_force:=clampf(speed*speed*.00085*coefficient,-260,350)*alignment*alignment
	var force:=frame.z*throttle*38+wing_lift*lift_force+Vector3.DOWN*48
	force-=velocity*(.025+speed*.00018+brake*.65+absf(attack)*.12)
	force-=frame.x*velocity.dot(frame.x)*1.6
	velocity=(velocity+force*dt).limit_length(470)
	p.air_velocity=velocity
	p.air_position+=velocity*dt
	p.speed=velocity.length()

static func crash(p:Dictionary)->void:
	p.crashed=true
	p.airborne=false
	p.recovery=2.0
	p.boost=0.0
	p.on_pad=false
	p.energy=maxf(0,p.energy-25)
	p.lift=0.0
	p.lift_speed=0.0
	p.unload=0.0

static func step(p:Dictionary,track:RefCounted,dt:float,steer:float,strafe:float,throttle:float,brake:float)->void:
	p.air_time+=dt
	var previous:Vector3=p.air_position
	integrate_air(p,dt,steer,strafe,throttle,brake)
	var position:Vector3=p.air_position
	var velocity:Vector3=p.air_velocity
	var frame:Basis=p.air_frame
	p.air_travel+=previous.distance_to(position)
	# Distance/race progress stays at launch until an actual legal track landing.
	var nearest:Dictionary=track.project(position,p.distance,p.air_travel*1.35+100)
	var n:Dictionary=nearest.node
	var before:float=(previous-n.p).dot(n.frame.y)-HOVER
	var after:float=(position-n.p).dot(n.frame.y)-HOVER
	p.lift=after
	p.lift_speed=velocity.dot(n.frame.y)
	var inside:bool=absf(nearest.lateral)<n.width-5.8
	if p.air_time>.10 and inside and before>0 and after<=0:
		var nose_alignment:float=frame.z.dot(n.frame.z)
		var upright:float=frame.y.dot(n.frame.y)
		var approach:float=velocity.dot(n.frame.z)
		if nose_alignment>.65 and upright>.65 and p.lift_speed> -75 and approach>65:
			p.airborne=false
			p.distance=nearest.distance
			p.x=nearest.lateral
			p.heading=clampf(atan2(-frame.z.dot(n.frame.x),frame.z.dot(n.frame.z)),-.7,.7)
			p.slip=clampf(-velocity.dot(n.frame.x),-70,70)
			p.speed=clampf(approach/maxf(.55,cos(p.heading)),65,440)
			p.lift=maxf(0,after)
			p.lift_speed=0.0
			p.unload=0.0
			p.landing_frame=frame
			p.landing_blend=1.0
			p.launch_cooldown=.7
		else:
			crash(p)
	elif p.air_time>.10 and inside and before< -2 and after>=-2:
		crash(p) # Hitting the underside cannot attach to the road.
	elif p.air_time>10 or position.y< -270 or position.distance_to(n.p)>850:
		crash(p)
