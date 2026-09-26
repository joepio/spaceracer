extends RefCounted
## World-space arcade flight. No road force or track-frame following after launch.
const HOVER:=1.3
const AIR_SPEED:=235.
const Track=preload("res://src/track.gd")

static func ground_basis(frame:Basis,heading:float,trim:float,slip:float)->Basis:
	# The mesh nose is +Z: negative X rotation raises it. Back-stick trim is negative.
	return frame*Basis(Vector3.UP,-heading)*Basis(Vector3.FORWARD,slip*.004)*Basis(Vector3.RIGHT,trim*(.32 if trim<0 else .16))

static func hover_height(trim:float)->float:
	return HOVER+maxf(0,-trim)*.45

static func ground_pose(p:Dictionary,n:Dictionary,clock:float)->Transform3D:
	var frame:=ground_basis(Track.surface_frame(n,p.x),p.heading,p.trim,p.slip)
	# Small physical warning: the suspension extends and the wings gently buffet.
	var buffet:float=p.unload*.018*sin(clock*19+p.slot)
	frame=frame*Basis(Vector3.RIGHT,-p.unload*.08)*Basis(Vector3.BACK,buffet)
	if p.landing_blend>0:
		frame=frame.slerp(p.landing_frame,p.landing_blend).orthonormalized()
	return Transform3D(frame,Track.point(n,p.x,hover_height(p.trim)+p.lift))

static func pose(p:Dictionary,n:Dictionary,clock:float)->Transform3D:
	if p.airborne or p.crashed:
		return Transform3D(p.air_frame,p.air_position)
	var result:=ground_pose(p,n,clock)
	# Cosmetic only: grid warmup cannot change launch speed or physical grip.
	var left:=smoothstep(0,.7,p.startup)
	var right:=smoothstep(.25,1,p.startup)
	result.origin-=Track.surface_frame(n,p.x).y*(1-(left+right)*.5)*.8
	result.basis=result.basis*Basis(Vector3.BACK,(left-right)*.12)
	return result

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
	p.air_entry_speed=p.air_velocity.length()
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
	var desired:=Vector3(p.trim*1.8,-yaw_input*1.65,roll_input*3.8)*authority
	p.air_rates=p.air_rates.lerp(desired,1-exp(-dt*24))
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
	var lift_force:=clampf(speed*speed*.0011*coefficient,-260,350)*alignment*alignment
	var force:=frame.z*throttle*52+wing_lift*lift_force+Vector3.DOWN*48
	force-=velocity*(.035+speed*.00075+brake*.65+absf(attack)*.12)
	force-=frame.x*velocity.dot(frame.x)*3.2
	# Preserve launch momentum, then smoothly settle below road cruise speed.
	var limit:=maxf(AIR_SPEED,float(p.get("air_entry_speed",AIR_SPEED))-70.*p.air_time)
	velocity=(velocity+force*dt).limit_length(limit)
	p.air_velocity=velocity
	p.air_position+=velocity*dt
	p.speed=velocity.length()

static func crash(p:Dictionary,normal:Vector3=Vector3.ZERO)->void:
	if p.crashed: return
	p.crash_velocity=p.air_velocity if p.airborne else p.ground_velocity
	p.crash_normal=normal
	p.crashed=true
	p.airborne=false
	p.recovery=0.0
	p.wreck_wait=true
	p.wreck_time=0.
	p.crash_id+=1
	p.speed=0.
	p.boost=0.0
	p.on_pad=false
	p.energy=maxf(0,p.energy-25)
	p.lift=0.0
	p.lift_speed=0.0
	p.unload=0.0
	p.thrust=0.;p.engine_power=0.;p.acceleration=0.;p.braking=0.
	p.input_throttle=0.;p.input_steer=0.;p.input_pitch=0.;p.input_strafe=0.;p.input_brake=0.

static func step(p:Dictionary,track:RefCounted,dt:float,steer:float,strafe:float,throttle:float,brake:float)->void:
	p.air_time+=dt
	var previous:Vector3=p.air_position
	integrate_air(p,dt,strafe,steer,throttle,brake)
	var position:Vector3=p.air_position
	if track.get("obstacles")!=null:
		var contact:Dictionary=track.obstacles.trace(previous,position)
		if not contact.is_empty():
			p.air_position=contact.position
			crash(p,contact.normal)
			return
	var velocity:Vector3=p.air_velocity
	var frame:Basis=p.air_frame
	p.air_travel+=previous.distance_to(position)
	# Distance/race progress stays at launch until an actual legal track landing.
	var nearest:Dictionary=track.project(position,p.distance,p.air_travel*1.35+100)
	var previous_hit:Dictionary=track.project(previous,p.distance,p.air_travel*1.35+100)
	var n:Dictionary=nearest.node
	var surface:=Track.surface_frame(n,nearest.lateral)
	var surface_position:=Track.point(n,nearest.lateral)
	# Compare each endpoint against the surface beneath it. Reusing today's
	# plane for yesterday's position can miss a rising landing ramp entirely.
	var previous_surface:=Track.surface_frame(previous_hit.node,previous_hit.lateral)
	var before:float=(previous-Track.point(previous_hit.node,previous_hit.lateral)).dot(previous_surface.y)-HOVER
	var after:float=(position-surface_position).dot(surface.y)-HOVER
	p.lift=after
	p.lift_speed=velocity.dot(surface.y)
	var inside:=Track.supported(n,nearest.lateral,5.8)
	var legal_progress:bool=nearest.distance-p.distance<=p.air_travel*1.05+25.
	if p.air_time>.10 and inside and before>0 and after<=0:
		var nose_alignment:float=frame.z.dot(surface.z)
		var upright:float=frame.y.dot(surface.y)
		var approach:float=velocity.dot(surface.z)
		var landing_pad:bool=n.get("feature","") in ["jump","flight"]
		# Purpose-built landing decks have stronger magnetic capture. A hard
		# touchdown still costs speed/energy; steep or misaligned impacts crash.
		var descent_limit:=100. if landing_pad else 75.
		if nose_alignment>.65 and upright>.65 and p.lift_speed> -descent_limit and approach>65 and legal_progress:
			var impact:=clampf((-p.lift_speed-45.)/55.,0.,1.) if landing_pad else 0.
			p.airborne=false
			p.distance=nearest.distance
			p.x=nearest.lateral
			p.route=signf(p.x) if float(n.get("split_gap",0.))>.01 else 0.
			p.heading=clampf(atan2(-frame.z.dot(surface.x),frame.z.dot(surface.z)),-.7,.7)
			p.slip=clampf(-velocity.dot(surface.x),-70,70)
			p.speed=clampf(approach/maxf(.55,cos(p.heading)),65,440)*(1.-impact*.18)
			p.energy=maxf(0.,p.energy-impact*6.)
			p.flash=maxf(p.flash,impact*.15)
			p.lift=maxf(0,after)
			p.lift_speed=0.0
			p.unload=0.0
			p.landing_frame=frame
			p.landing_blend=1.0
			p.launch_cooldown=.7
		else:
			crash(p,surface.y)
	elif p.air_time>.10 and inside and before< -2 and after>=-2:
		crash(p,-surface.y) # Hitting the underside cannot attach to the road.
	elif p.air_time>.10 and inside and after< -2 and previous_hit.node.get("air_gap",false):
		crash(p) # A low approach hits the exposed landing lip; never flies through it.
	elif p.air_time>10 or position.y< -179.5 or position.distance_to(n.p)>850 or (track.has_method("hits_water") and track.hits_water(position)):
		crash(p)
