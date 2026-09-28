extends RefCounted
## Race-owned, deterministic combat. No rendering or wall-clock dependencies.
const DiveBomb=preload("res://src/dive_bomb.gd")
const Railgun=preload("res://src/railgun.gd")
const Track=preload("res://src/track.gd")
const Flight=preload("res://src/flight.gd")
const Impact=preload("res://src/impact_vfx.gd")
const NAMES:={"missile":"Cruise missile","warp":"Warp drive","drone":"Sentry gun","emp":"EMP","bomb":"Glide bomb","railgun":"Railgun"}
const WARP_DURATION:=2.8
const EMP_VISUAL_RADIUS:=220. # Visual shell only; gameplay range is map-wide.
const EMP_EXPAND:=.65
const EMP_DURATION:=2.2
const MISSILE_LASER_TIME:=.75
const MISSILE_TRAIL_POINTS:=48
const MISSILE_SPEED:=1500./3.6
const MISSILE_LAUNCH_TIME:=1.05
const MISSILE_MOUNT:=preload("res://src/racer_design.gd").SOCKET
const SENTRY_MOUNT:=preload("res://src/racer_design.gd").SOCKET
const SENTRY_PIVOT:=Vector3(0.,.8,0.)
const SENTRY_INTERVAL:=.05 # 20 rounds/sec; same 10 shield damage/sec as 4 every .4 sec.
const SENTRY_DAMAGE:=10.*SENTRY_INTERVAL
const MISSILE_BLAST_LIFE:=2.4
const MISSILE_BLAST_RADIUS:=32.
var pulses:Array[Dictionary]=[]
var pickups:Array[Dictionary]=[]
var missiles:Array[Dictionary]=[]
var bombs:Array[Dictionary]=[]
var rail_shots:Array[Dictionary]=[]
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
			# Sparse weapon rows preserve their established seeded placement.
			if station%6==0:
				for lane in [-.58,0.,.58]:
					pickups.append({"distance":distance,"x":n.width*lane,"claimed":{},"cooldown":0.,"reveal":1.,"pose":Transform3D(n.frame,Track.point(n,n.width*lane,5.))})
			station+=1
			distance+=760.
		else: distance+=35.

static func initialize(p:Dictionary)->void:
	p.merge({"weapon":"","fire_held":false,"weapon_acquired":0.,"warp_time":0.,"warp_age":0.,"warp_fx":0.,
		"drone_time":0.,"drone_cooldown":0.,"drone_target":-1,"shield_hit":0.,"weapon_guard":0.,
		"missile_warning":0.,"evade_notice":0.,"last_jink":-10.,"jinking":false,"combat_g":0.,
		"landing_damage":0.,"emp_time":0.,"emp_guard":0.,
		"pickup_fx":0.,"pickup_pose":Transform3D.IDENTITY,
		"pickup_energy":false,"energy_fx":0.,"energy_gained":0.},true)
	p.impact_id=0;p.impact_age=Impact.LIFE
	p.destruction_notices=[]
	p.rail_armed=false;p.rail_hold=0.;p.rail_view={}
	p.bomb_armed=false;p.bomb_preview={}

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
	# Share the sentry slice with railguns, preserving warp/missile catch-up odds.
	roll=(roll-.16)/.84
	# Reserve a rare slice of sentry odds; leave catch-up warp odds intact.
	if roll>1.-lerpf(.055,.095,clampf((rank-1.)/maxf(1.,count-1.),0.,1.)): return "bomb"
	if roll>=odds.x+odds.y and roll<odds.x+odds.y+minf(.14,odds.z*.45): return "railgun"
	return "missile" if roll<odds.x else ("warp" if roll<odds.x+odds.y else "drone")

func begin_step(race:RefCounted,dt:float,inputs:Array)->void:
	for pickup in pickups:
		pickup.cooldown=maxf(0.,pickup.cooldown-dt)
		if pickup.cooldown<=0.: pickup.reveal=minf(1.,pickup.reveal+dt*6.)
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		for notice in p.destruction_notices: notice.life-=dt
		p.destruction_notices=p.destruction_notices.filter(func(notice):return notice.life>0.)
		if p.finished: continue # Victory owns cosmetic timers; keep the loadout.
		p.weapon_before=p.distance;p.weapon_x_before=p.x
		p.weapon_position_before=p.air_position;p.weapon_was_airborne=p.airborne
		p.weapon_velocity=p.air_velocity if p.airborne else p.ground_velocity
		p.shield_hit=maxf(0.,p.shield_hit-dt)
		p.impact_age=minf(Impact.LIFE,p.impact_age+dt)
		p.weapon_guard=maxf(0.,p.weapon_guard-dt)
		p.evade_notice=maxf(0.,p.evade_notice-dt)
		p.pickup_fx=maxf(0.,p.pickup_fx-dt)
		p.energy_fx=maxf(0.,p.energy_fx-dt)
		p.emp_time=maxf(0.,p.emp_time-dt)
		p.emp_guard=maxf(0.,p.emp_guard-dt)
		p.missile_warning=0.
		p.warp_fx=move_toward(p.warp_fx,1. if p.warp_time>0. else 0.,dt*4.)
		var fire:bool=inputs[i].get("fire",false)
		p.rail_view=inputs[i].get("rail_view",{})
		Railgun.input_step(self,race,i,fire,dt)
		DiveBomb.input_step(self,race,i,fire,dt)
		if p.weapon not in ["railgun","bomb"] and race.countdown<=0. and fire and not p.fire_held: activate(race,i)
		p.fire_held=fire
		if not available(p):
			p.weapon="";p.warp_time=0.;p.drone_time=0.;p.drone_target=-1
			p.emp_time=0.

func activate(race:RefCounted,index:int)->bool:
	var p:Dictionary=race.racers[index]
	if not available(p) or p.warp_time>0. or p.drone_time>0. or race.over: return false
	match p.weapon:
		"railgun":
			if p.emp_time>0.: return false
			Railgun.fire(self,race,index)
		"bomb":
			if not DiveBomb.ready(race,p): return false
			var aim:=DiveBomb.acquire(race,p,DiveBomb.launch_state(race,p))
			serial+=1
			var payload:=DiveBomb.launch_state(race,p)
			payload.merge({"id":serial,"owner":index,"age":0.,"distance":p.distance,"target":aim.target})
			bombs.append(payload)
		"emp":
			if pulses.any(func(pulse):return pulse.owner==index): return false
			serial+=1
			pulses.append({"id":serial,"owner":index,"frame":pose(race,p),"age":0.,"radius":0.,"hit":{}})
		"missile":
			if p.emp_time>0.: return false
			var target_index:=missile_target(race,index)
			if missiles.any(func(m):return m.owner==index): return false
			serial+=1
			var frame:=pose(race,p)
			var inherited:Vector3=p.air_velocity if p.airborne else frame.basis.z*p.speed
			var origin:=frame*MISSILE_MOUNT
			missiles.append({"id":serial,"owner":index,"target":target_index,"unguided":target_index<0,"unguided_fuse":2.8+fposmod(serial*.618,1.)*1.4,"distance":p.distance,
				"position":origin,"velocity":inherited,"launch_origin":origin,"launch_basis":frame.basis,
				"launch_velocity":inherited,"launch_speed":minf(MISSILE_SPEED,p.speed),"launch_travel":0.,
				"x":p.x,"age":0.,"locked":false,"terminal":-1.,"evaded":false,"disabled":false,"fade":.7,"trail":[],"trail_time":0.})
		"warp":
			if p.airborne or p.emp_time>0.: return false
			p.warp_time=WARP_DURATION;p.warp_age=0.;p.boost=0.;p.slide=0.;p.slip=0.;p.heading=0.
		"drone":
			p.drone_time=8.;p.drone_cooldown=.25
		_: return false
	p.weapon=""
	return true

static func emp_glitch(p:Dictionary)->float:
	if p.emp_time<=0.: return 0.
	var age:=maxf(0.,EMP_DURATION-float(p.emp_time))
	return 1.-smoothstep(0.,.5,age)

func step_emp(race:RefCounted,dt:float)->void:
	for pulse in pulses.duplicate():
		pulse.active=pulse.age<=EMP_EXPAND and available(race.racers[pulse.owner])
		pulse.age+=dt
		pulse.radius=EMP_VISUAL_RADIUS*minf(1.,pulse.age/EMP_EXPAND)
		if pulse.active and pulse.age<=EMP_EXPAND+dt:
			for i in range(race.racers.size()):
				var p:Dictionary=race.racers[i]
				if i==pulse.owner or pulse.hit.has(i) or not available(p): continue
				pulse.hit[i]=true
				if p.emp_guard>0. or p.weapon_guard>0.: continue
				# Warp loses propulsion too; over a gap, retain real flight momentum.
				if p.warp_time>0. and race.track.sample(p.distance).air_gap:
					Flight.launch(p,race.track.sample(p.distance),race.clock)
				p.emp_time=EMP_DURATION;p.emp_guard=EMP_DURATION+2.
				p.warp_time=0.;p.boost=0.;p.on_pad=false
				p.engine_power=0.;p.thrust=0.;p.acceleration=0.;p.input_throttle=0.;p.brake_vfx=0.
		if pulse.age>1.05: pulses.erase(pulse)
	for missile in missiles:
		intercept_missile(missile,missile.position,missile.position)

func intercept_missile(missile:Dictionary,_from:Vector3,_to:Vector3)->bool:
	if missile.get("disabled",false): return true
	for pulse in pulses:
		# Map-wide shutdown during the active pulse; visual shell size is cosmetic.
		if not pulse.get("active",pulse.age<=EMP_EXPAND): continue
		missile.disabled=true;missile.evaded=true;missile.fade=1.1
		return true
	return false

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
	if n.split_gap>.01:
		var route:float=n.get("preferred_route",0.)
		if route==0.: route=1. if p.slot%2==0 else -1.
		lane=route*(n.split_gap+(n.width-n.split_gap)*.5)
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

func damage(race:RefCounted,p:Dictionary,amount:float,slowdown:float,source:Vector3=Vector3.INF,owner:int=-1)->bool:
	if not available(p) or p.warp_time>0. or p.weapon_guard>0.: return false
	var hit_frame:=pose(race,p)
	var local_hit:=Vector3(0.,.65,-2.2)
	if source.is_finite():
		var direction:Vector3=(hit_frame.basis.inverse()*(source-hit_frame.origin)).normalized()
		local_hit=Vector3(direction.x*3.8,maxf(.2,direction.y*1.1),direction.z*2.8)
	Impact.record(p,hit_frame,local_hit,amount)
	p.energy=maxf(0.,p.energy-amount)
	p.shield_hit=.28;p.flash=.16
	p.speed*=slowdown
	if p.airborne: p.air_velocity*=slowdown
	if amount>20.: p.weapon_guard=1.1
	if p.energy<=0.:
		var frame:=pose(race,p)
		p.air_position=frame.origin;p.air_frame=frame.basis
		Flight.crash(p)
		if owner>=0 and owner<race.racers.size() and race.racers[owner]!=p:
			var notices:Array=race.racers[owner].destruction_notices
			notices.append({"name":str(p.get("name","Pilot %d"%(p.slot+1))),"life":.5})
			while notices.size()>3: notices.pop_front()
	return true

static func drone_position(race:RefCounted,p:Dictionary)->Vector3:
	# The legacy inventory key remains "drone"; the sentry is now hull-mounted.
	return pose(race,p)*(SENTRY_MOUNT+SENTRY_PIVOT)

func detonate_missile(race:RefCounted,m:Dictionary,center:Vector3,approach:Vector3)->void:
	if not missiles.has(m) or m.get("disabled",false): return
	# A single world-space sphere, so nearby airborne craft are affected too.
	# The direct victim receives one full hit, never a second splash hit.
	for i in range(race.racers.size()):
		if i==m.owner: continue
		var p:Dictionary=race.racers[i]
		var offset:Vector3=pose(race,p).origin-center
		var direct:bool=i==m.target
		var strength:=1. if direct else pow(maxf(0.,1.-offset.length()/MISSILE_BLAST_RADIUS),.8)
		if strength<=0.: continue
		if not damage(race,p,38. if direct else 26.*strength,.66 if direct else 1.-.20*strength,approach if direct else center,m.owner): continue
		if p.crashed: continue
		var surface:Basis=Track.surface_frame(race.track.sample(p.distance),p.x)
		var sideways:Vector3=-surface.x
		var side:=signf(offset.dot(sideways))
		if absf(offset.dot(sideways))<.5:
			side=signf((center-approach).dot(sideways))
			if side==0.: side=1. if p.slot%2==0 else -1.
		if p.airborne:
			var direction:=offset.normalized() if offset.length_squared()>1. else (sideways*side+surface.y*.25).normalized()
			p.air_velocity+=direction*60.*strength
			p.speed=p.air_velocity.length()
		else:
			p.slip+=side*60.*strength
			p.slide=maxf(p.slide,.9*strength)
			p.slide_hold=maxf(p.slide_hold,.55*strength)
	bursts.append({"id":m.id,"position":center,"life":MISSILE_BLAST_LIFE})
	missiles.erase(m)

static func sentry_basis(race:RefCounted,p:Dictionary)->Basis:
	var frame:=pose(race,p)
	if p.drone_target<0: return frame.basis
	var direction:=pose(race,race.racers[p.drone_target]).origin-drone_position(race,p)
	if direction.length_squared()<.01: return frame.basis
	return Basis.looking_at(direction.normalized(),frame.basis.y,true)

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
		if p.finished: continue
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
		if p.finished: continue
		if not available(p): p.drone_time=0.;p.warp_time=0.;p.weapon=""
		p.drone_target=-1
		if p.drone_time<=0.: continue
		var firing_dt:=minf(dt,p.drone_time)
		p.drone_time=maxf(0.,p.drone_time-dt)
		p.drone_cooldown-=firing_dt
		p.drone_target=drone_target(race,i)
		if p.drone_target<0:
			p.drone_cooldown=maxf(0.,p.drone_cooldown)
			continue
		while p.drone_cooldown<=.0000001:
			p.drone_cooldown+=SENTRY_INTERVAL
			var target:Dictionary=race.racers[p.drone_target]
			if not available(target): break
			var from:=drone_position(race,p)+sentry_basis(race,p)*Vector3(0.,0.,2.6)
			var to:=pose(race,target).origin
			if race.track.obstacles!=null and not race.track.obstacles.trace(from,to,.1).is_empty(): continue
			# Preserve both DPS and the old cumulative slowing per second.
			damage(race,target,SENTRY_DAMAGE,pow(.995,SENTRY_INTERVAL/.4),from,i)
			shots.append({"owner":i,"from":from,"to":to,"life":.15})

	for m in missiles.duplicate(): step_missile(race,m,dt)
	for bomb in bombs.duplicate(): DiveBomb.step(self,race,bomb,dt)
	for list in [shots,bursts,rail_shots]:
		for effect in list.duplicate():
			effect.life-=dt
			if effect.life<=0.: list.erase(effect)
	while bursts.size()>24: bursts.pop_front()

static func missile_eta(race:RefCounted,m:Dictionary)->float:
	if m.evaded or m.get("disabled",false) or m.target<0: return INF
	var target:Dictionary=race.racers[m.target]
	if not available(target): return INF
	var offset:Vector3=pose(race,target).origin-Vector3(m.position)
	if m.terminal>=0.:
		var velocity:Vector3=target.air_velocity if target.airborne else target.ground_velocity
		return maxf(0.,offset.length()-4.)/maxf(1.,MISSILE_SPEED-velocity.dot(offset.normalized()))
	var progress:float=target.distance
	if target.airborne: progress=race.track.project(target.air_position,target.distance,target.air_travel*1.35+100.).distance
	var closing:=maxf(1.,MISSILE_SPEED-target.speed*cos(target.heading))
	return maxf(0.,progress-m.distance)/closing+maxf(0.,MISSILE_LAUNCH_TIME-m.age)

static func missile_target(race:RefCounted,owner:int)->int:
	# Finishing racers stay first in the results table, but are no longer targets.
	for candidate in race.standings():
		var index:int=race.racers.find(candidate)
		if index!=owner and available(candidate): return index
	return -1

static func laser_strength(race:RefCounted,m:Dictionary)->float:
	var eta:=missile_eta(race,m)
	if not is_finite(eta) or m.get("disabled",false) or eta>=MISSILE_LASER_TIME: return 0.
	# Fade in from nothing, saving the strongest contact bloom for impact.
	# A locked target can pull away; lock alone must never keep the beam lit.
	var proximity:=1.-clampf(eta/MISSILE_LASER_TIME,0.,1.)
	return proximity*proximity

static func record_missile_trail(m:Dictionary)->void:
	var direction:Vector3=m.velocity.normalized() if m.velocity.length_squared()>.01 else m.launch_basis.z
	var nozzle:Vector3=m.position-direction*2.6
	if m.trail.is_empty(): m.trail.append(nozzle);return
	var start:Vector3=m.trail[0]
	var span:=start.distance_to(nozzle)
	for i in range(1,mini(MISSILE_TRAIL_POINTS, floori(span/6.))+1):
		m.trail.push_front(start.lerp(nozzle,i*6./span))
	while m.trail.size()>MISSILE_TRAIL_POINTS: m.trail.pop_back()

func step_missile(race:RefCounted,m:Dictionary,dt:float)->void:
	m.age+=dt
	if m.age>90.: missiles.erase(m);return
	# Once a laser could be seen, do not steal the warning from that pilot.
	if not m.evaded and not m.get("disabled",false) and not m.get("unguided",false):
		if m.terminal>=0. or missile_eta(race,m)<MISSILE_LASER_TIME: m.locked=true
		if not m.get("locked",false):
			var current:=missile_target(race,m.owner)
			if current>=0: m.target=current
		if missile_eta(race,m)<MISSILE_LASER_TIME: m.locked=true
	var target:Dictionary=race.racers[m.target] if m.target>=0 else {}
	if not target.is_empty() and not available(target):
		if not m.evaded: m.evaded=true;m.fade=.7

	if m.get("disabled",false):
		# Dead electronics and motor: retain momentum, fall, and never detonate.
		m.velocity+=Vector3.DOWN*24.*dt;m.position+=m.velocity*dt;m.fade-=dt
		if m.fade<=0.: missiles.erase(m)
		return
	if m.age>.18: record_missile_trail(m)
	if m.evaded:
		m.position+=m.velocity.normalized()*MISSILE_SPEED*dt;m.fade-=dt
		if m.fade<=0.: missiles.erase(m)
		return
	var previous:Vector3=m.position
	if m.age<MISSILE_LAUNCH_TIME:
		m.launch_speed=move_toward(m.launch_speed,MISSILE_SPEED,620.*maxf(0.,m.age-maxf(.18,m.age-dt)))
	else: m.launch_speed=MISSILE_SPEED
	if m.get("unguided",false):
		# No target is still a real launch: eject, accelerate away, then burst.
		var direction:Vector3=(m.launch_basis.z+m.launch_basis.y*.18).normalized()
		m.velocity=m.launch_velocity.lerp(direction*m.launch_speed,smoothstep(0.,MISSILE_LAUNCH_TIME,m.age))
		m.position+=m.velocity*dt
		m.position+=m.launch_basis.y*7.*(smoothstep(0.,.38,m.age)-smoothstep(0.,.38,m.age-dt))
		m.distance+=m.launch_speed*dt
		if intercept_missile(m,previous,m.position): return
		if m.age>=m.unguided_fuse: detonate_missile(race,m,m.position,previous)
		return
	var destination:=pose(race,target).origin
	if m.terminal<0.:
		# Cruise follows the seeded ribbon, including banks, loops and jump paths.
		# No rubber-band speed or world-space lerp that cuts across tight corners.
		m.distance+=m.launch_speed*dt
		m.launch_travel+=m.launch_speed*dt
		var n:Dictionary=race.track.sample(m.distance)
		m.x=move_toward(m.x,clampf(target.x,-n.width*.7,n.width*.7),dt*18.)
		if n.split_gap>0.: m.x=(1. if m.x>=0. else -1.)*maxf(absf(m.x),n.split_gap+6.)
		m.position=Track.point(n,m.x,10.)
		if m.age<MISSILE_LAUNCH_TIME:
			# Inherit the craft's motion, eject upward, then blend smoothly onto the
			# cruise ribbon as the rocket accelerates. No spawn teleport or speed snap.
			var inherited_speed:float=minf(MISSILE_SPEED,m.launch_velocity.length())
			var free:Vector3=m.launch_origin+m.launch_velocity*m.age+m.launch_basis.z*(m.launch_travel-inherited_speed*m.age)
			free+=m.launch_basis.y*7.*smoothstep(0.,.38,m.age)
			m.position=free.lerp(m.position,smoothstep(.18,MISSILE_LAUNCH_TIME,m.age))
			m.velocity=(m.position-previous)/maxf(dt,.001)
			# Nearby targets can be acquired after clearing the rack, even if the
			# launch has already carried the missile past their route position.
			if m.age>.38 and m.position.distance_to(destination)<180. and target.distance-m.distance<100.: m.terminal=1.
			intercept_missile(m,previous,m.position)
			return
		var range_to_target:float=m.position.distance_to(destination)
		var target_progress:float=target.distance
		if target.airborne: target_progress=race.track.project(target.air_position,target.distance,target.air_travel*1.35+100.).distance
		if absf(target_progress-m.distance)<65. and range_to_target<(180. if target.airborne else 55.): m.terminal=1.
	else:
		var offset:Vector3=destination-m.position
		var distance:=offset.length()
		var direction:=offset.normalized()
		var target_velocity:Vector3=target.air_velocity if target.airborne else target.ground_velocity
		var closing:=maxf(1.,m.launch_speed-target_velocity.dot(direction))
		m.terminal=maxf(0.,distance-4.)/closing
		# The leader can still break lock with a fresh, late high-G manoeuvre.
		if m.terminal<.23 and race.clock-target.last_jink<.23 and target.last_jink>=race.clock-dt-.001:
			m.evaded=true;target.evade_notice=1.2
			return
		m.position+=direction*minf(m.launch_speed*dt,distance)
		if intercept_missile(m,previous,m.position): return
		if distance<=m.launch_speed*dt+4.:
			detonate_missile(race,m,destination,previous)
	m.velocity=(m.position-previous)/maxf(dt,.001)
	intercept_missile(m,previous,m.position)
