extends RefCounted
## World-space arcade flight. No road force or track-frame following after launch.
const HOVER:=1.3

static func ground_basis(frame:Basis,heading:float,trim:float,slip:float)->Basis:
	# The mesh nose is +Z: negative X rotation raises it. Back-stick trim is negative.
	return frame*Basis(Vector3.UP,-heading)*Basis(Vector3.FORWARD,slip*.004)*Basis(Vector3.RIGHT,trim*(.32 if trim<0 else .16))

static func hover_height(trim:float)->float:
	return HOVER+maxf(0,-trim)*.45

static func launch(p:Dictionary,n:Dictionary)->void:
	p.airborne=true
	p.air_time=0.0
	p.air_travel=0.0
	p.air_roll=0.0
	p.air_frame=ground_basis(n.frame,p.heading,p.trim,p.slip).orthonormalized()
	p.air_position=n.p-n.frame.x*p.x+n.frame.y*(hover_height(p.trim)+.2)
	# Preserve launch momentum; pitching the hull does not instantly rotate velocity.
	p.air_velocity=n.frame.z*p.speed*maxf(.55,cos(p.heading))-n.frame.x*p.slip+n.frame.y*24
	p.lift=.2
	p.on_pad=false
	p.slide=0.0
	p.drifting=false
	p.launch_charge=0.0

static func crash(p:Dictionary)->void:
	p.crashed=true
	p.airborne=false
	p.recovery=2.0
	p.boost=0.0
	p.on_pad=false
	p.energy=maxf(0,p.energy-25)
	p.lift=0.0
	p.lift_speed=0.0

static func step(p:Dictionary,track:RefCounted,dt:float,steer:float,strafe:float,throttle:float,brake:float)->void:
	p.air_time+=dt
	var frame:Basis=p.air_frame
	# Left stick banks/turns. Right stick Y pitches; X remains a weaker air strafe.
	var roll:float=move_toward(p.air_roll,steer*.5,dt*1.7)
	frame=(frame*Basis(Vector3.RIGHT,p.trim*1.25*dt)*Basis(Vector3.UP,-steer*1.1*dt)*Basis(Vector3.BACK,roll-p.air_roll)).orthonormalized()
	p.air_roll=roll
	p.air_frame=frame
	var velocity:Vector3=p.air_velocity
	var speed:=velocity.length()
	var airflow:=velocity.normalized() if speed>1 else frame.z
	var alignment:=clampf(frame.z.dot(airflow),0,1)
	var wing_lift:=frame.y-airflow*frame.y.dot(airflow)
	if wing_lift.length_squared()>.001: wing_lift=wing_lift.normalized()
	# Lift decays in a stall; holding the nose up cannot climb indefinitely.
	var attack:=asin(clampf(frame.z.dot(wing_lift),-1,1))
	var lift_factor:=clampf(.7+attack*2.8,0,1.9)
	var lift_force:=minf(140,speed*speed*.00075*lift_factor)*alignment*alignment
	var force:=frame.z*throttle*32+wing_lift*lift_force+Vector3.DOWN*48
	force-=velocity*(.065+brake*.7)
	force-=frame.x*velocity.dot(frame.x)*1.6
	force-=frame.x*strafe*24
	velocity+=force*dt
	velocity=velocity.limit_length(470)
	var previous:Vector3=p.air_position
	var position:=previous+velocity*dt
	p.air_travel+=previous.distance_to(position)
	p.air_position=position
	p.air_velocity=velocity
	p.speed=velocity.length()
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
			p.lift=0.0
			p.lift_speed=0.0
			p.launch_charge=0.0
			p.launch_cooldown=.7
		else:
			crash(p)
	elif p.air_time>.10 and inside and before< -2 and after>=-2:
		crash(p) # Hitting the underside cannot attach to the road.
	elif p.air_time>10 or position.y< -270 or position.distance_to(n.p)>850:
		crash(p)
