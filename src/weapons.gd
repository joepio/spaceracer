extends RefCounted
## Race-owned, deterministic combat. No rendering or wall-clock dependencies.
const Track=preload("res://src/track.gd")
const Flight=preload("res://src/flight.gd")
const NAMES:={"missile":"Cruise missile","warp":"Warp drive","drone":"Sentry drone","emp":"EMP","jammer":"Jammer"}
const WARP_DURATION:=2.8
const JAMMER_RANGE:=260.
const JAMMER_HALF_ANGLE:=28.
const EMP_RADIUS:=220.
const EMP_EXPAND:=.65
const EMP_DURATION:=2.2
const BATTERY_ENERGY:=25.
const MISSILE_SPEED:=1500./3.6
const MISSILE_BLAST_LIFE:=2.4
var pulses:Array[Dictionary]=[]
var pickups:Array[Dictionary]=[]
var batteries:Array[Dictionary]=[]
var missiles:Array[Dictionary]=[]
var shots:Array[Dictionary]=[]
var bursts:Array[Dictionary]=[]
var rng:=RandomNumberGenerator.new()
var serial:=0

func _init(track:RefCounted)->void:
	rng.seed=track.seed_value+918371
	var distance:=360.
	var station:=0
	while distance<track.length-250.:
		var n:Dictionary=track.sample(distance)
		if not n.loop and not n.air_gap and n.split_gap<.01 and n.feature=="ribbon" and absf(n.curve)<.007 and track.jump_at(distance,220.).is_empty():
			# Keep one in three original stations, retaining lane choice at each.
			if station%3==0:
				for lane in [-.58,0.,.58]:
					pickups.append({"distance":distance,"x":n.width*lane,"claimed":{},"cooldown":0.,"reveal":1.,"pose":Transform3D(n.frame,Track.point(n,n.width*lane,5.))})
			elif station%3==1:
				for lane in [-.58,0.,.58]:
					batteries.append({"distance":distance,"x":n.width*lane,"claimed":{},"cooldown":0.,"reveal":1.,"pose":Transform3D(n.frame,Track.point(n,n.width*lane,4.))})
			station+=1
			distance+=760.
		else: distance+=35.

static func initialize(p:Dictionary)->void:
	p.merge({"weapon":"","fire_held":false,"weapon_acquired":0.,"warp_time":0.,"warp_age":0.,"warp_fx":0.,
		"drone_time":0.,"drone_cooldown":0.,"drone_target":-1,"shield_hit":0.,"weapon_guard":0.,
		"missile_warning":0.,"evade_notice":0.,"last_jink":-10.,"jinking":false,"combat_g":0.,
		"landing_damage":0.,"emp_time":0.,"emp_guard":0.,
		"jammer_time":0.,"jammer_deploy":0.,"jam_strength":0.,"pickup_fx":0.,"pickup_pose":Transform3D.IDENTITY,
		"pickup_energy":false,"energy_fx":0.,"energy_gained":0.},true)

static func available(p:Dictionary)->bool:
	return not p.finished and not p.crashed and p.recovery<=0.

static func pose(race:RefCounted,p:Dictionary)->Transform3D:
	return Flight.pose(p,race.track.sample(p.distance),race.clock)

static func weights(rank:int,count:int,gap:float=0.)->Vector3:
	var behind:=clampf((rank-1.)/maxf(1.,count-1.),0.,1.)
	var missile:=lerpf(.18,.30,behind)
	# Warp is a catch-up item: distance matters even in a two-player race.
	var warp:=0. if rank<=1 else lerpf(.08,.20,behind)+.40*smoothstep(150.,1500.,gap)
	return Vector3(missile,warp,1.-missile-warp)

func choose(rank:int,count:int,gap:float=0.)->String:
	var odds:=weights(rank,count,gap)
	var roll:=rng.randf()
	if roll<.16: return "emp"
	if roll<.30: return "jammer"
	roll=(roll-.30)/.70
	return "missile" if roll<odds.x else ("warp" if roll<odds.x+odds.y else "drone")

func begin_step(race:RefCounted,dt:float,inputs:Array)->void:
	for pickup in pickups+batteries:
		pickup.cooldown=maxf(0.,pickup.cooldown-dt)
		if pickup.cooldown<=0.: pickup.reveal=minf(1.,pickup.reveal+dt*6.)
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		p.weapon_before=p.distance;p.weapon_x_before=p.x
		p.weapon_velocity=p.air_velocity if p.airborne else p.ground_velocity
		p.shield_hit=maxf(0.,p.shield_hit-dt)
		p.weapon_guard=maxf(0.,p.weapon_guard-dt)
		p.evade_notice=maxf(0.,p.evade_notice-dt)
		p.pickup_fx=maxf(0.,p.pickup_fx-dt)
		p.energy_fx=maxf(0.,p.energy_fx-dt)
		p.emp_time=maxf(0.,p.emp_time-dt)
		p.emp_guard=maxf(0.,p.emp_guard-dt)
		p.jammer_time=maxf(0.,p.jammer_time-dt)
		p.missile_warning=0.
		p.warp_fx=move_toward(p.warp_fx,1. if p.warp_time>0. else 0.,dt*4.)
		var fire:bool=inputs[i].get("fire",false)
		if race.countdown<=0. and fire and not p.fire_held: activate(race,i)
		p.fire_held=fire
		if not available(p):
			p.weapon="";p.warp_time=0.;p.drone_time=0.;p.drone_target=-1
			p.emp_time=0.
			p.jammer_time=0.
		p.jammer_deploy=move_toward(p.jammer_deploy,1. if p.jammer_time>0. else 0.,dt*5.)
	step_jammers(race)

func activate(race:RefCounted,index:int)->bool:
	var p:Dictionary=race.racers[index]
	if not available(p) or p.warp_time>0. or p.drone_time>0. or p.jammer_time>0. or race.over: return false
	match p.weapon:
		"jammer":
			if p.emp_time>0.: return false
			p.jammer_time=6.
		"emp":
			if pulses.any(func(pulse):return pulse.owner==index): return false
			serial+=1
			pulses.append({"id":serial,"owner":index,"frame":pose(race,p),"age":0.,"radius":0.,"hit":{}})
		"missile":
			var leader:Dictionary=race.standings()[0]
			if leader==p or not available(leader) or leader.warp_time>0.: return false
			if missiles.any(func(m):return m.owner==index): return false
			serial+=1
			var frame:=pose(race,p)
			missiles.append({"id":serial,"owner":index,"target":race.racers.find(leader),"distance":p.distance,
				"position":frame.origin+frame.basis.y*9.,"velocity":frame.basis.z*MISSILE_SPEED,"x":p.x,"age":0.,"terminal":-1.,"evaded":false,"fade":.7,"trail":[],"trail_time":0.})
		"warp":
			if p.airborne or p.emp_time>0.: return false
			p.warp_time=WARP_DURATION;p.warp_age=0.;p.boost=0.;p.slide=0.;p.slip=0.;p.heading=0.
		"drone":
			p.drone_time=8.;p.drone_cooldown=.25
		_: return false
	p.weapon=""
	return true

static func jammer_strength(source:Transform3D,target:Vector3)->float:
	var offset:=target-source.origin
	var distance:=offset.length()
	if distance<.01 or distance>=JAMMER_RANGE: return 0.
	var facing:=offset.dot(source.basis.z)/distance
	var edge:=cos(deg_to_rad(JAMMER_HALF_ANGLE))
	return (1.-smoothstep(15.,JAMMER_RANGE,distance))*smoothstep(edge,cos(deg_to_rad(12.)),facing)

func step_jammers(race:RefCounted)->void:
	for p in race.racers: p.jam_strength=0.
	for owner in race.racers:
		if not available(owner) or owner.jammer_time<=0. or owner.emp_time>0.: continue
		var source:=pose(race,owner)
		for target in race.racers:
			if target==owner or not available(target) or target.warp_time>0. or target.weapon_guard>0.: continue
			target.jam_strength=maxf(target.jam_strength,jammer_strength(source,pose(race,target).origin))

static func interference_noise(time:float,seed_value:float)->float:
	var tick:=floorf(time*8.)
	var fraction:=smoothstep(0.,1.,fposmod(time*8.,1.))
	var a:=fposmod(sin(tick*127.1+seed_value*311.7)*43758.5453,1.)*2.-1.
	var b:=fposmod(sin((tick+1.)*127.1+seed_value*311.7)*43758.5453,1.)*2.-1.
	return lerpf(a,b,fraction)

func jam_inputs(race:RefCounted,inputs:Array)->Array:
	var result:Array=inputs.duplicate()
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		if p.jam_strength<=0. or race.countdown>0.: continue
		var input:Dictionary=inputs[i].duplicate()
		var seed_value:float=race.track.seed_value+p.slot*17.
		for axis in ["steer","strafe","trim"]:
			var channel:int=["steer","strafe","trim"].find(axis)
			var disturbance:float=interference_noise(race.clock,seed_value+channel*31.)*p.jam_strength*[.38,.32,.18][channel]
			input[axis]=clampf(float(input.get(axis,0.))+disturbance,-1.,1.)
		result[i]=input
	return result

func step_emp(race:RefCounted,dt:float)->void:
	for pulse in pulses.duplicate():
		pulse.age+=dt
		pulse.radius=EMP_RADIUS*minf(1.,pulse.age/EMP_EXPAND)
		if pulse.age<=EMP_EXPAND+dt:
			for i in range(race.racers.size()):
				var p:Dictionary=race.racers[i]
				if i==pulse.owner or pulse.hit.has(i) or not available(p): continue
				if pose(race,p).origin.distance_to(pulse.frame.origin)>pulse.radius: continue
				pulse.hit[i]=true
				if p.emp_guard>0. or p.weapon_guard>0.: continue
				# Warp loses propulsion too; over a gap, retain real flight momentum.
				if p.warp_time>0. and race.track.sample(p.distance).air_gap:
					Flight.launch(p,race.track.sample(p.distance),race.clock)
				p.emp_time=EMP_DURATION;p.emp_guard=EMP_DURATION+2.
				p.warp_time=0.;p.boost=0.;p.on_pad=false
				p.engine_power=0.;p.thrust=0.;p.acceleration=0.;p.input_throttle=0.;p.brake_vfx=0.
		if pulse.age>1.05: pulses.erase(pulse)

func step_warp(race:RefCounted,p:Dictionary,dt:float)->void:
	var before:=pose(race,p)
	p.warp_age+=dt
	p.warp_time=maxf(0.,p.warp_time-dt)
	var upcoming:Dictionary=race.track.sample(p.distance+65.)
	var exit_speed:=clampf(1.65/maxf(.001,absf(upcoming.curve)),135.,265.)
	var speed:=lerpf(exit_speed,530.,smoothstep(0.,.4,p.warp_age)*smoothstep(0.,.6,p.warp_time))
	p.speed=move_toward(p.speed,speed,dt*850.)
	p.distance+=p.speed*dt
	var n:Dictionary=race.track.sample(p.distance)
	# Phase over missing deck, and do not hand back control in the middle of a gap.
	if n.air_gap and p.warp_time<.65: p.warp_time=.65
	var lane:=0.
	if n.split_gap>.01: lane=(1. if p.slot%2==0 else -1.)*(n.split_gap+(n.width-n.split_gap)*.5)
	p.x=move_toward(p.x,lane,dt*90.)
	p.heading=0.;p.slip=0.;p.trim=0.;p.unload=0.;p.lift=0.;p.slide=0.;p.drifting=false
	p.airborne=false;p.landing_blend=0.;p.braking=0.;p.on_pad=false;p.thrust=1.;p.engine_power=1.;p.input_throttle=1.
	p.acceleration=240.;p.input_steer=0.;p.input_pitch=0.;p.input_strafe=0.;p.input_brake=0.
	race.constrain_surface(p,n)
	p.ground_velocity=(pose(race,p).origin-before.origin)/dt
	p.launch_cooldown=.5
	race.update_lap(p)
	if p.finished: p.warp_time=0.

func collect(race:RefCounted,p:Dictionary)->void:
	if not available(p) or p.airborne or p.warp_time>0. or p.warp_fx>.05 or not p.weapon.is_empty(): return
	var start:float=p.weapon_before
	var end:float=p.distance
	if end<=start or end-start>120.: return # Recovery/teleports never sweep up items.
	for pickup in pickups:
		if pickup.cooldown>0.: continue
		var circuit:=floori((end-pickup.distance)/race.track.length)
		var crossing:float=pickup.distance+circuit*race.track.length
		if circuit<0 or crossing<start or crossing>end: continue
		if pickup.claimed.get(p.slot,-1)>=circuit: continue
		var lateral:=lerpf(p.weapon_x_before,p.x,(crossing-start)/maxf(.001,end-start))
		if absf(lateral-pickup.x)>7.: continue
		var ordered:Array=race.standings()
		p.weapon=choose(ordered.find(p)+1,ordered.size(),maxf(0.,ordered[0].distance-p.distance))
		if ordered[0]==p and p.weapon=="missile": p.weapon="drone"
		p.weapon_acquired=race.clock
		pickup.cooldown=2.;pickup.reveal=0.
		p.pickup_fx=.45;p.pickup_pose=pickup.pose
		p.pickup_energy=false
		# Only this lane disappears globally; one item per row/lap for each racer.
		for other in pickups:
			if other.distance==pickup.distance: other.claimed[p.slot]=circuit
		return

func collect_energy(race:RefCounted,p:Dictionary)->void:
	if not available(p) or p.airborne or p.warp_time>0. or p.warp_fx>.05 or p.energy>=100.: return
	var start:float=p.weapon_before
	var end:float=p.distance
	if end<=start or end-start>120.: return
	for battery in batteries:
		if battery.cooldown>0.: continue
		var circuit:=floori((end-battery.distance)/race.track.length)
		var crossing:float=battery.distance+circuit*race.track.length
		if circuit<0 or crossing<start or crossing>end or battery.claimed.get(p.slot,-1)>=circuit: continue
		var lateral:=lerpf(p.weapon_x_before,p.x,(crossing-start)/maxf(.001,end-start))
		if absf(lateral-battery.x)>5.: continue
		p.energy_gained=minf(BATTERY_ENERGY,100.-p.energy)
		p.energy+=p.energy_gained;p.energy_fx=.8
		p.pickup_fx=.45;p.pickup_pose=battery.pose;p.pickup_energy=true
		battery.cooldown=2.;battery.reveal=0.
		for other in batteries:
			if other.distance==battery.distance: other.claimed[p.slot]=circuit
		return

func damage(race:RefCounted,p:Dictionary,amount:float,slowdown:float)->bool:
	if not available(p) or p.warp_time>0. or p.weapon_guard>0.: return false
	p.energy=maxf(0.,p.energy-amount)
	p.shield_hit=.28;p.flash=.16
	p.speed*=slowdown
	if p.airborne: p.air_velocity*=slowdown
	if amount>20.: p.weapon_guard=1.1
	if p.energy<=0.:
		var frame:=pose(race,p)
		p.air_position=frame.origin;p.air_frame=frame.basis
		Flight.crash(p)
	return true

static func drone_position(race:RefCounted,p:Dictionary)->Vector3:
	var frame:=pose(race,p)
	var orbit:float=race.clock*.7+p.slot
	return frame.origin+frame.basis*Vector3(cos(orbit)*7.,4.5+sin(orbit*2.)*.35,3.+sin(orbit)*5.)

func drone_target(race:RefCounted,owner:int)->int:
	var p:Dictionary=race.racers[owner]
	var frame:=pose(race,p)
	var nearest:=-1;var closest:=220.
	for i in range(race.racers.size()):
		var target:Dictionary=race.racers[i]
		if i==owner or not available(target) or target.warp_time>0.: continue
		var ahead:float=target.distance-p.distance
		if ahead<=0. or ahead>=closest: continue
		var offset:=pose(race,target).origin-frame.origin
		if offset.length()>190. or offset.normalized().dot(frame.basis.z)<.15: continue
		closest=ahead;nearest=i
	return nearest

func end_step(race:RefCounted,dt:float)->void:
	step_emp(race,dt)
	for p in race.racers:
		var velocity:Vector3=p.air_velocity if p.airborne else p.ground_velocity
		var change:Vector3=(velocity-p.weapon_velocity)/maxf(dt,.001)
		var direction:=velocity.normalized()
		p.combat_g=(change-direction*change.dot(direction)).length()/9.81
		var sharp_input:bool=absf(p.input_steer)>.82 or (p.airborne and maxf(absf(p.input_strafe),absf(p.input_pitch))>.85)
		var jink:bool=available(p) and p.combat_g>=24. and sharp_input and (p.slide>.4 or p.airborne)
		if jink and not p.jinking: p.last_jink=race.clock
		p.jinking=jink
		collect_energy(race,p)
		collect(race,p)
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		if not available(p): p.drone_time=0.;p.warp_time=0.;p.weapon=""
		p.drone_target=-1
		if p.drone_time<=0.: continue
		p.drone_time=maxf(0.,p.drone_time-dt)
		p.drone_cooldown-=dt
		p.drone_target=drone_target(race,i)
		if p.drone_target<0 or p.drone_cooldown>0.: continue
		p.drone_cooldown=.4
		var target:Dictionary=race.racers[p.drone_target]
		var from:=drone_position(race,p)
		var to:=pose(race,target).origin
		if race.track.obstacles!=null and not race.track.obstacles.trace(from,to,.1).is_empty(): continue
		damage(race,target,4.,.995)
		shots.append({"from":from,"to":to,"life":.12})
	for m in missiles.duplicate(): step_missile(race,m,dt)
	for list in [shots,bursts]:
		for effect in list.duplicate():
			effect.life-=dt
			if effect.life<=0.: list.erase(effect)
	while bursts.size()>24: bursts.pop_front()

static func missile_eta(race:RefCounted,m:Dictionary)->float:
	if m.evaded: return INF
	var target:Dictionary=race.racers[m.target]
	if not available(target): return INF
	var offset:Vector3=pose(race,target).origin-Vector3(m.position)
	if m.terminal>=0.:
		var velocity:Vector3=target.air_velocity if target.airborne else target.ground_velocity
		return maxf(0.,offset.length()-4.)/maxf(1.,MISSILE_SPEED-velocity.dot(offset.normalized()))
	var progress:float=target.distance
	if target.airborne: progress=race.track.project(target.air_position,target.distance,target.air_travel*1.35+100.).distance
	var closing:=maxf(1.,MISSILE_SPEED-target.speed*cos(target.heading))
	return maxf(0.,progress-m.distance)/closing

func step_missile(race:RefCounted,m:Dictionary,dt:float)->void:
	var target:Dictionary=race.racers[m.target]
	m.age+=dt
	if not available(target) or target.warp_time>0. or not available(race.racers[m.owner]) or m.age>90.:
		missiles.erase(m);return
	m.trail_time+=dt
	if m.trail_time>=.05:
		m.trail_time=fmod(m.trail_time,.05);m.trail.push_front(m.position)
		if m.trail.size()>16: m.trail.pop_back()
	if m.evaded:
		m.position+=m.velocity.normalized()*MISSILE_SPEED*dt;m.fade-=dt
		if m.fade<=0.: missiles.erase(m)
		return
	var destination:=pose(race,target).origin
	var previous:Vector3=m.position
	if m.terminal<0.:
		# Cruise follows the seeded ribbon, including banks, loops and jump paths.
		# No rubber-band speed or world-space lerp that cuts across tight corners.
		m.distance+=MISSILE_SPEED*dt
		var n:Dictionary=race.track.sample(m.distance)
		m.x=move_toward(m.x,clampf(target.x,-n.width*.7,n.width*.7),dt*18.)
		if n.split_gap>0.: m.x=(1. if m.x>=0. else -1.)*maxf(absf(m.x),n.split_gap+6.)
		m.position=Track.point(n,m.x,10.)
		var range_to_target:float=m.position.distance_to(destination)
		var target_progress:float=target.distance
		if target.airborne: target_progress=race.track.project(target.air_position,target.distance,target.air_travel*1.35+100.).distance
		if absf(target_progress-m.distance)<65. and range_to_target<(180. if target.airborne else 55.): m.terminal=1.
	else:
		var offset:Vector3=destination-m.position
		var distance:=offset.length()
		var direction:=offset.normalized()
		var target_velocity:Vector3=target.air_velocity if target.airborne else target.ground_velocity
		var closing:=maxf(1.,MISSILE_SPEED-target_velocity.dot(direction))
		m.terminal=maxf(0.,distance-4.)/closing
		# The leader can still break lock with a fresh, late high-G manoeuvre.
		if m.terminal<.23 and race.clock-target.last_jink<.23 and target.last_jink>=race.clock-dt-.001:
			m.evaded=true;target.evade_notice=1.2
			return
		m.position+=direction*minf(MISSILE_SPEED*dt,distance)
		if distance<=MISSILE_SPEED*dt+4.:
			damage(race,target,38.,.66)
			bursts.append({"id":m.id,"position":destination,"life":MISSILE_BLAST_LIFE})
			missiles.erase(m)
	m.velocity=(m.position-previous)/maxf(dt,.001)
