extends RefCounted
## Race-owned, deterministic combat. No rendering or wall-clock dependencies.
const Track=preload("res://src/track.gd")
const Flight=preload("res://src/flight.gd")
const NAMES:={"missile":"Cruise missile","warp":"Warp drive","drone":"Sentry drone"}
const WARP_DURATION:=2.8
var pickups:Array[Dictionary]=[]
var missiles:Array[Dictionary]=[]
var shots:Array[Dictionary]=[]
var bursts:Array[Dictionary]=[]
var rng:=RandomNumberGenerator.new()
var serial:=0

func _init(track:RefCounted)->void:
	rng.seed=track.seed_value+918371
	var distance:=360.
	while distance<track.length-250.:
		var n:Dictionary=track.sample(distance)
		if not n.loop and not n.air_gap and n.split_gap<.01 and n.feature=="ribbon" and absf(n.curve)<.007 and track.jump_at(distance,220.).is_empty():
			for lane in [-.58,0.,.58]:
				pickups.append({"distance":distance,"x":n.width*lane,"claimed":{},"pose":Transform3D(n.frame,Track.point(n,n.width*lane,5.))})
			distance+=760.
		else: distance+=35.

static func initialize(p:Dictionary)->void:
	p.merge({"weapon":"","fire_held":false,"weapon_acquired":0.,"warp_time":0.,"warp_age":0.,"warp_fx":0.,
		"drone_time":0.,"drone_cooldown":0.,"drone_target":-1,"shield_hit":0.,"weapon_guard":0.,
		"missile_warning":0.,"evade_notice":0.,"last_jink":-10.,"jinking":false,"combat_g":0.},true)

static func available(p:Dictionary)->bool:
	return not p.finished and not p.crashed and p.recovery<=0.

static func pose(race:RefCounted,p:Dictionary)->Transform3D:
	return Flight.pose(p,race.track.sample(p.distance),race.clock)

static func weights(rank:int,count:int)->Vector3:
	var behind:=clampf((rank-1.)/maxf(1.,count-1.),0.,1.)
	# The front still gets useful items; positions change odds, never driving speed.
	return Vector3(.18,.28,.54).lerp(Vector3(.30,.36,.34),behind)

func choose(rank:int,count:int)->String:
	var odds:=weights(rank,count)
	var roll:=rng.randf()
	return "missile" if roll<odds.x else ("warp" if roll<odds.x+odds.y else "drone")

func begin_step(race:RefCounted,dt:float,inputs:Array)->void:
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		p.weapon_before=p.distance;p.weapon_x_before=p.x
		p.weapon_velocity=p.air_velocity if p.airborne else p.ground_velocity
		p.shield_hit=maxf(0.,p.shield_hit-dt)
		p.weapon_guard=maxf(0.,p.weapon_guard-dt)
		p.evade_notice=maxf(0.,p.evade_notice-dt)
		p.missile_warning=0.
		p.warp_fx=move_toward(p.warp_fx,1. if p.warp_time>0. else 0.,dt*4.)
		var fire:bool=inputs[i].get("fire",false)
		if race.countdown<=0. and fire and not p.fire_held: activate(race,i)
		p.fire_held=fire
		if not available(p):
			p.weapon="";p.warp_time=0.;p.drone_time=0.;p.drone_target=-1

func activate(race:RefCounted,index:int)->bool:
	var p:Dictionary=race.racers[index]
	if not available(p) or p.warp_time>0. or p.drone_time>0. or race.over: return false
	match p.weapon:
		"missile":
			var leader:Dictionary=race.standings()[0]
			if leader==p or not available(leader) or leader.warp_time>0.: return false
			if missiles.any(func(m):return m.owner==index): return false
			serial+=1
			var frame:=pose(race,p)
			missiles.append({"id":serial,"owner":index,"target":race.racers.find(leader),"distance":p.distance,
				"position":frame.origin+frame.basis.y*7.,"velocity":frame.basis.z*620.,"age":0.,"terminal":-1.,"evaded":false,"fade":.7})
		"warp":
			if p.airborne: return false
			p.warp_time=WARP_DURATION;p.warp_age=0.;p.boost=0.;p.slide=0.;p.slip=0.;p.heading=0.
		"drone":
			p.drone_time=8.;p.drone_cooldown=.25
		_: return false
	p.weapon=""
	return true

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
		var circuit:=floori((end-pickup.distance)/race.track.length)
		var crossing:float=pickup.distance+circuit*race.track.length
		if circuit<0 or crossing<start or crossing>end: continue
		if pickup.claimed.get(p.slot,-1)>=circuit: continue
		var lateral:=lerpf(p.weapon_x_before,p.x,(crossing-start)/maxf(.001,end-start))
		if absf(lateral-pickup.x)>7.: continue
		var ordered:Array=race.standings()
		p.weapon=choose(ordered.find(p)+1,ordered.size())
		if ordered[0]==p and p.weapon=="missile": p.weapon="drone"
		p.weapon_acquired=race.clock
		# A row is personal, so the leader cannot strip every item from the pack.
		for other in pickups:
			if other.distance==pickup.distance: other.claimed[p.slot]=circuit
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
	for p in race.racers:
		var velocity:Vector3=p.air_velocity if p.airborne else p.ground_velocity
		var change:Vector3=(velocity-p.weapon_velocity)/maxf(dt,.001)
		var direction:=velocity.normalized()
		p.combat_g=(change-direction*change.dot(direction)).length()/9.81
		var sharp_input:bool=absf(p.input_steer)>.82 or (p.airborne and maxf(absf(p.input_strafe),absf(p.input_pitch))>.85)
		var jink:bool=available(p) and p.combat_g>=24. and sharp_input and (p.slide>.4 or p.airborne)
		if jink and not p.jinking: p.last_jink=race.clock
		p.jinking=jink
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

func step_missile(race:RefCounted,m:Dictionary,dt:float)->void:
	var target:Dictionary=race.racers[m.target]
	m.age+=dt
	if not available(target) or target.warp_time>0. or not available(race.racers[m.owner]) or m.age>12.:
		missiles.erase(m);return
	if m.evaded:
		m.position+=m.velocity*dt;m.fade-=dt
		if m.fade<=0.: missiles.erase(m)
		return
	var destination:=pose(race,target).origin
	target.missile_warning=maxf(target.missile_warning,1. if m.terminal<0. else 2.)
	var previous:Vector3=m.position
	if m.terminal<0.:
		var catchup:=clampf((target.distance-m.distance)*.45,330.,1500.)
		m.distance+=maxf(660.,target.speed+catchup)*dt
		var n:Dictionary=race.track.sample(m.distance)
		var chase:=Track.point(n,target.x,10.)
		m.position=m.position.lerp(chase,1.-exp(-dt*14.))
		if target.distance-m.distance<170.: m.terminal=.55
	else:
		m.terminal-=dt
		# A sharp manoeuvre must START during the final 230 ms. Holding a turn
		# well before the warning does not roll a random dodge chance.
		if m.terminal<.23 and race.clock-target.last_jink<.23 and target.last_jink>=race.clock-dt-.001:
			m.evaded=true;target.evade_notice=1.2
			return
		m.position=m.position.lerp(destination,clampf(dt/maxf(dt,m.terminal+dt),0.,1.))
		if m.terminal<=0.:
			damage(race,target,38.,.66)
			bursts.append({"position":destination,"life":.45})
			missiles.erase(m)
	m.velocity=(m.position-previous)/maxf(dt,.001)
