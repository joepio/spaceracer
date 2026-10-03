extends RefCounted
const Track = preload("res://src/track.gd")
const Weapons=preload("res://src/weapons.gd")
const Flight=preload("res://src/flight.gd")
const Bump=preload("res://src/bump.gd")
const Victory=preload("res://src/victory.gd")
const Slipstream=preload("res://src/slipstream.gd")
const Checkpoints=preload("res://src/checkpoints.gd")
const TOP_SPEED := 265.0
const BOOST_SPEED := 390.0
const STACK_BOOST_SPEED := 475.0
const MAX_SPEED := 520.0
const CRASH_RESPAWN_DELAY := 2.0
const ENERGY_REFILL_RATE := 1.5
const ENERGY_REFILL_DELAY := 2.0
# Full visible hull, including swept wings; local nose is slightly ahead of origin.
const HULL_HALF_WIDTH := 4.7
const HULL_HALF_LENGTH := 4.45
const HULL_CENTER := .65
var boost_cost := 22.0
var boost_duration := 1.25
var energy_refill := 1.0
var respawn_seconds := CRASH_RESPAWN_DELAY
var weapons:RefCounted
var checkpoints:RefCounted
var track: RefCounted
var racers: Array[Dictionary] = []
var countdown := 3.0
var clock := 0.0
var vfx_clock := 0.0
var laps := 3
var over := false
var finish_deadline := INF

func _init(roster: Array, track_seed: int, lap_count: int = 3, difficulty:String="normal", biome:String="city") -> void:
	track = Track.new(track_seed,difficulty,biome)
	checkpoints=Checkpoints.new(track)
	laps = lap_count
	for i in range(roster.size()):
		var p: Dictionary = roster[i].duplicate(true)
		p.wreck=null;p.crash_velocity=Vector3.ZERO;p.crash_normal=Vector3.ZERO
		p.merge({"distance": -floorf(i / 3.0) * 13.0, "x": (i % 3 - (mini(3, roster.size()) - 1) / 2.0) * 12.0, "speed": 0.0,
			"heading": 0.0, "slip": 0.0, "slipstream":0., "energy": 100.0, "boost": 0.0, "boost_held": false,"reset_held":false,"manual_reset":false,"wreck_wait":false,"wreck_time":0.,"crash_id":0,"air_entry_speed":235.,
			"input_throttle":0.0,"engine_power":0.0,"startup":0.0,"ignited":false,"brake_vfx":0.0,"slide_hold":0.0,"acceleration":0.0,"input_steer":0.0,"input_strafe":0.0,"input_pitch":0.0,"input_brake":0.0,"air_position":Vector3.ZERO,"air_velocity":Vector3.ZERO,"air_frame":Basis.IDENTITY,
			"ground_velocity":Vector3.ZERO,"air_rates":Vector3.ZERO,"unload":0.0,"landing_frame":Basis.IDENTITY,"landing_blend":0.0,"air_time":0.0,"air_travel":0.0,"air_roll":0.0,"launch_cooldown":0.0,"crashed":false,"trim": 0.0, "lift": 0.0, "lift_speed": 0.0, "airborne": false, "slide": 0.0, "braking": 0.0, "thrust": 0.0, "flash": 0.0, "recovery": 0.0, "lap": 1, "rank": i + 1, "finished": false,
			"time": INF, "best_lap": INF, "lap_start": 0.0, "drifting": false, "on_pad": false}, true)
		Weapons.initialize(p)
		Bump.initialize(p)
		checkpoints.initialize(p)
		p.energy_previous=p.energy;p.energy_refill_delay=ENERGY_REFILL_DELAY
		p.rebuild_time=0.
		p.ai_boost_lap=1;p.ai_boost_cycle=0;p.ai_boost_seen=false;p.ai_boost_ready_at=0.
		racers.append(p)
	weapons=Weapons.new(track)

static func speed_instability(speed:float,planted:float)->float:
	# Progressive loss of magnetic adhesion, controllable with nose-down trim.
	return smoothstep(365.,510.,speed)*(1.-clampf(planted,0.,1.)*.72)

func bot(p: Dictionary) -> Dictionary:
	if p.crashed or p.finished: return {}
	if p.lap>p.ai_boost_lap:
		p.ai_boost_lap=p.lap
		p.ai_boost_ready_at=clock+bot_boost_delay(p,.15,1.5)
	if p.boost>0. and not p.ai_boost_seen:
		p.ai_boost_seen=true;p.ai_boost_cycle+=1
		p.ai_boost_ready_at=clock+p.boost+bot_boost_delay(p,.2,1.1)
	elif p.boost<=0.: p.ai_boost_seen=false
	if p.airborne: return air_bot(p)
	var n:Dictionary=track.sample(p.distance)
	var hard:bool=track.difficulty=="hard"
	var peak:=absf(n.curve)
	# Corner limits constrain braking; cruising speed is not a braking limit.
	# Otherwise normal/easy bots brake away their own boost on straight road.
	var boost_ceiling:float=STACK_BOOST_SPEED if n.zone=="boost" else BOOST_SPEED
	var safe_speed:=boost_ceiling
	# Hard pilots carry speed with coordinated yaw/strafe instead of holding
	# half brake through every bend. Ordinary pilots keep their gentler pace.
	# Include the current apex on hard so late recovery still requests braking.
	for ahead in ([0.,30.,65.,110.,165.] if hard else [30.,65.,110.,165.]):
		var upcoming:Dictionary=n if ahead==0. else track.sample(p.distance+ahead)
		var bend:=absf(upcoming.curve)
		peak=maxf(peak,bend)
		var corner_speed:=clampf((2.7 if hard else 1.65)/maxf(.001,bend),160. if hard else 125.,boost_ceiling)
		if upcoming.feature=="hairpin": corner_speed=clampf(1.5/maxf(.001,bend),75.,BOOST_SPEED)
		safe_speed=minf(safe_speed,sqrt(corner_speed*corner_speed+2*150*ahead))
	var brake:=clampf((p.speed-safe_speed)/35.0,0,1)
	if not hard and absf(n.curve)>.006 and p.speed>145: brake=maxf(brake,.48)
	var target:float=n.width*Track.Recharge.CENTER if n.zone=="repair" and p.energy<85 else sin(p.slot*2)*4
	if float(n.get("split_gap",0.))>.01:
		var route:float=n.get("preferred_route",0.)
		if route==0.: route=p.get("route",0.)
		if route==0: route=1. if p.slot%2==0 else -1.
		target=route*(n.split_gap+(n.width-n.split_gap)*.5)
	# Move before the fork locks the pilot to a branch.
	var fork:Dictionary=track.sample(p.distance+120.)
	if n.split_gap<.01 and fork.preferred_route!=0.: target=fork.preferred_route*15.
	var slide:float=p.slide
	var grip:=lerpf(14,1.8,slide)
	var inertia:=lerpf(.25,1,slide)
	var desired_lateral:=clampf((target-p.x)*2.4,-45,45)
	var lateral_demand:float=desired_lateral+n.curve*p.speed*p.speed*inertia/grip
	# Share cornering between yaw and real right-stick strafe, just like a pilot.
	var strafe:=clampf(lateral_demand*.30/46.,-.65,.65)
	var desired_heading:=asin(clampf((lateral_demand-strafe*46.)/maxf(p.speed,60),-.75,.75))
	var turn:=clampf((n.curve*p.speed+desired_heading*lerpf(3.5,.8,slide)+(desired_heading-p.heading)*3.8+(desired_lateral-p.slip)*.012)/lerpf(1.65,3.8,slide),-1,1)
	# Keep momentum and a centred approach before a mandatory jump.
	var jump:Dictionary=track.jump_at(p.distance,180.)
	if not jump.is_empty() and fposmod(p.distance,track.length)<jump.takeoff: brake=0.
	# Spend a useful burst on the exit, retaining enough hull energy for a hit.
	# Never latch the boost button while EMP/recovery prevents activation, or
	# Combine paid boost with free pads when the road ahead permits it.
	var boost_ready:bool=clock>=p.ai_boost_ready_at and p.recovery==0. and p.emp_time<=0. and p.warp_time<=0. and not p.boost_held
	if hard: boost_ready=boost_ready and p.unload<.25 and absf(p.x-target)<n.width*.5
	return {"steer":turn,"strafe":strafe,"throttle":1.0,"brake":brake,"left":false,"right":false,
		"fire":(Weapons.Railgun.opportunity(self,p) if p.weapon=="railgun" else p.weapon != "" and clock-p.weapon_acquired>.9 and not p.fire_held),"boost":boost_ready and p.lap>1 and p.energy>(30. if hard else 40.) and peak<(.0055 if hard else .0025) and p.boost==0 and brake<.05 and track.jump_at(p.distance,500.).is_empty()}

func bot_boost_delay(p:Dictionary,minimum:float,maximum:float)->float:
	var rng:=RandomNumberGenerator.new()
	rng.seed=track.seed_value*9176+p.slot*131+p.lap*7919+p.ai_boost_cycle*104729
	return rng.randf_range(minimum,maximum)

func air_bot(p:Dictionary)->Dictionary:
	var hit:Dictionary=track.project(p.air_position,p.distance,p.air_travel*1.35+100.)
	var n:Dictionary=hit.node
	var ahead:=100.
	var jump:Dictionary=track.jump_at(p.distance,20.)
	var destination:float=hit.distance+ahead
	if not jump.is_empty():
		var landing:float=floorf(p.distance/track.length)*track.length+jump.landing+40.
		destination=maxf(destination,landing)
	var aim:Dictionary=track.sample(destination)
	var frame:Basis=p.air_frame
	# Lead the displaced landing centre and cancel drift before reaching the deck.
	# Aim through the hover plane so direct jet steering completes touchdown
	# instead of asymptotically skimming just above it until flight times out.
	var target:Vector3=Track.point(aim,0.,-.5)
	var desired:Vector3=(target-p.air_position).normalized()*220.
	var goal:Vector3=desired+(desired-p.air_velocity)*.8
	return {"fire":Weapons.Railgun.opportunity(self,p) if p.weapon=="railgun" else Weapons.DiveBomb.opportunity(self,p),"throttle":.85,"brake":clampf((p.speed-235.)/100.,0.,.25),
		"trim":clampf(-atan2(goal.dot(frame.y),maxf(20.,goal.dot(frame.z)))*1.6,-1.,1.),
		"steer":clampf(-atan2(goal.dot(frame.x),maxf(20.,goal.dot(frame.z)))*3.,-1.,1.),
		"strafe":clampf(-atan2(aim.frame.y.dot(frame.x),aim.frame.y.dot(frame.y))*1.37,-1.,1.)}

static func can_reset(p:Dictionary)->bool:
	return ((p.airborne and p.air_time>.3) or p.get("checkpoint_missed",false)) and not p.crashed and p.recovery<=0 and not p.finished

static func begin_recovery(p:Dictionary,delay:float)->void:
	# Crashing already charged the penalty; preserve it during either recovery path.
	p.energy=maxf(1.,p.energy)
	p.manual_reset=true
	p.wreck_wait=false
	p.recovery=delay

func respawn_target(p:Dictionary)->Dictionary:
	# Camera and recovery must agree, including missed checkpoints and split decks.
	if p.get("respawn_target_id",-1)==p.crash_id: return p.respawn_target
	var distance:float=checkpoints.return_distance(p) if p.checkpoint_missed else p.distance
	if track.has_method("safe_respawn"): distance=track.safe_respawn(distance)
	var n:Dictionary=track.sample(distance)
	var x:=0.
	if float(n.get("split_gap",0.))>.01:
		x=(1. if p.slot%2==0 else -1.)*(n.split_gap+(n.width-n.split_gap)*.5)
	p.respawn_target={"distance":distance,"x":x,"pose":Transform3D(Track.surface_frame(n,x),Track.point(n,x,Flight.HOVER))}
	p.respawn_target_id=p.crash_id
	return p.respawn_target

func step(dt: float, inputs: Array) -> void:
	vfx_clock+=dt
	for p in racers:
		if p.finished: Victory.step(p,track,dt,clock)
	if over:
		return
	weapons.begin_step(self,dt,inputs)
	for i in range(racers.size()):
		var input:Dictionary=inputs[i]
		var pilot:Dictionary=racers[i]
		if pilot.finished: continue
		pilot.checkpoint_before=Flight.pose(pilot,track.sample(pilot.distance),clock).origin
		pilot.checkpoint_flash=maxf(0.,pilot.checkpoint_flash-dt)
		Bump.begin(pilot,input,dt,countdown)
		var reset_pressed:bool=input.get("reset",false)
		if countdown<=0 and reset_pressed and not pilot.reset_held and can_reset(pilot):
			if not pilot.airborne:
				var reset_pose:=Flight.pose(pilot,track.sample(pilot.distance),clock)
				pilot.air_position=reset_pose.origin;pilot.air_frame=reset_pose.basis
			Flight.crash(pilot)
			begin_recovery(pilot,respawn_seconds)
		pilot.reset_held=reset_pressed
		# Only recovery and pause remain available once the craft is destroyed.
		if pilot.crashed:
			pilot.input_throttle=0.;pilot.input_steer=0.;pilot.input_pitch=0.;pilot.input_strafe=0.;pilot.input_brake=0.
			pilot.thrust=0.;pilot.engine_power=0.;pilot.acceleration=0.;pilot.braking=0.
			continue
		pilot.input_throttle=clampf(float(input.get("throttle",0.0)),0,1)
		if pilot.emp_time>0.: pilot.input_throttle=0.
		var brake_input:=clampf(float(input.get("brake",0.0)),0,1)
		pilot.thrust=pilot.input_throttle*(1-brake_input) if pilot.recovery==0 and not pilot.finished and not pilot.crashed else 0.0
		pilot.engine_power=lerpf(pilot.engine_power,pilot.thrust,1-exp(-dt*16))
		pilot.brake_vfx=move_toward(pilot.brake_vfx,brake_input,dt*(18 if brake_input>pilot.brake_vfx else 3))
		if pilot.emp_time>0.: pilot.engine_power=0.;pilot.brake_vfx=0.
		if pilot.input_throttle>.05: pilot.ignited=true
		if pilot.ignited: pilot.startup=move_toward(pilot.startup,1.0,dt*(.8 if countdown>0 else 5.0))
		racers[i].input_steer=clampf(input.get("steer",0.0),-1,1)
		racers[i].input_pitch=clampf(input.get("trim",0.0),-1,1)
		racers[i].input_strafe=clampf(float(input.get("strafe",0.0)),-1,1)
		racers[i].input_brake=clampf(float(input.get("brake",0.0)),0,1)
	Slipstream.update(self,dt)
	if countdown > 0:
		countdown = maxf(0, countdown - dt)
		return
	clock += dt
	for i in range(racers.size()):
		var p := racers[i]
		var c: Dictionary = inputs[i]
		p.flash = maxf(0, p.flash - dt)
		p.rebuild_time=maxf(0.,p.rebuild_time-dt)
		p.launch_cooldown=maxf(0,p.launch_cooldown-dt)
		if p.finished:
			continue
		if p.crashed and p.wreck!=null: p.wreck.step(dt,track,p.distance)
		if p.wreck_wait:
			p.wreck_time+=dt
			p.speed=0.;p.thrust=0.
			if p.wreck_time<respawn_seconds: continue
			# Complete recovery this tick after the explosion/debris have played.
			begin_recovery(p,dt)
		if p.warp_time>0.:
			p.boost_held=c.get("boost",false)
			weapons.step_warp(self,p,dt)
			continue
		var n: Dictionary = track.sample(p.distance)
		var previous_pose:=Flight.ground_pose(p,n,clock-dt)
		p.landing_blend=maxf(0,p.landing_blend-dt*3)
		var steer := clampf(c.get("steer", 0), -1, 1)
		var throttle := clampf(c.get("throttle", 0), 0, 1)
		if p.emp_time>0.: throttle=0.
		var brake:=clampf(float(c.get("brake",0.0)),0,1)
		p.braking=brake
		p.thrust=throttle*(1-brake) if p.recovery==0 else 0.0
		var strafe:=clampf(float(c.get("strafe",0.0)),-1,1)
		if p.emp_time>0. and not p.airborne: strafe=0.
		var pitch_input:=clampf(float(c.get("trim",0.0)),-1,1)
		if p.crashed:
			steer=0.;throttle=0.;brake=0.;strafe=0.;pitch_input=0.;p.braking=0.
		p.trim=pitch_input if p.airborne else move_toward(p.trim,pitch_input,dt*5)
		var planted:float=maxf(0,p.trim)
		var loose:float=maxf(0,-p.trim)
		# A short brake pulse breaks adhesion quickly; recovery is deliberately slower.
		var slide_target:=sqrt(brake)*smoothstep(45,140,p.speed)*(1-planted*.55)
		if slide_target>p.slide:
			p.slide=move_toward(p.slide,slide_target,dt*14)
			p.slide_hold=.18
		elif brake>.08:
			p.slide=move_toward(p.slide,slide_target,dt*4)
			p.slide_hold=.18
		else:
			p.slide_hold=maxf(0,p.slide_hold-dt)
			if p.slide_hold==0 or planted>.2:
				var countersteer:=.6 if steer*p.heading<-.015 else 0.0
				p.slide=move_toward(p.slide,0.0,dt*(.65+planted*2.8+countersteer))
		p.drifting=p.slide>.18
		if c.get("boost", false) and not p.boost_held and p.lap > 1 and p.energy > boost_cost and p.recovery == 0 and brake<.05 and not p.airborne and p.emp_time<=0.:
			p.energy -= boost_cost
			p.boost = boost_duration
		p.boost_held = c.get("boost", false)
		p.boost = maxf(0, p.boost - dt)
		if p.recovery > 0:
			p.recovery = maxf(0, p.recovery - dt)
			p.speed = 0.0
			p.slide = 0.0
			p.lift = 0.0
			p.lift_speed = 0.0
			p.airborne = false
			p.unload=0.0
			p.air_rates=Vector3.ZERO
			p.landing_blend=0.0
			if p.recovery == 0:
				p.crashed=false
				p.wreck_time=0.
				p.wreck=null
				p.launch_cooldown=1.0
				p.weapon_guard=2.
				if not p.manual_reset: p.energy=65.
				elif p.energy<=1.: p.energy=25. # Rebuilt hull must survive the next mandatory landing.
				p.manual_reset=false
				var destination:=respawn_target(p)
				p.distance=destination.distance;p.x=destination.x;p.checkpoint_missed=false
				p.route=0.
				p.rebuild_time=.7
				p.heading = 0.0
				p.slip = 0.0
				p.speed = 90.0
			continue
		if p.airborne:
			var previous_speed:float=p.speed
			Flight.step(p,track,dt,steer,strafe,throttle,brake)
			p.acceleration=maxf(0,(p.speed-previous_speed)/dt)
			if not p.crashed and p.recovery==0:
				update_lap(p)
				if p.finished and p.get("air_gate_crossed",false): p.time=clock-dt*(1.-p.air_gate_fraction)
			continue
		p.on_pad = n.zone == "boost" and absf(p.x) < n.width * .35 and brake<.05 and p.lift<1 and p.emp_time<=0.
		var fast: bool = (p.boost > 0 or p.on_pad) and brake<.05
		var stacked:bool=fast and p.boost>0. and p.on_pad
		var target:float=(STACK_BOOST_SPEED if stacked else (BOOST_SPEED if fast else TOP_SPEED))+loose*60-planted*35
		var drag:float=Slipstream.drag_multiplier(p,fast)
		var acceleration: float = throttle * (1-brake*.9) * 125 * (1 - pow(p.speed / target, 2)*drag)
		if fast:
			acceleration += maxf(0, target - p.speed) * (4.2 if stacked else 3.)
		if throttle == 0:
			acceleration -= 38*drag
		acceleration -= 240*brake+planted*p.speed*.12
		acceleration -= absf(steer) * p.speed * lerpf(.045,.08,p.slide) + n.slope * 28*cos(p.heading)
		p.acceleration=maxf(0,acceleration)
		p.speed = clampf(p.speed + acceleration * dt, 0, MAX_SPEED)
		var instability:=speed_instability(p.speed,planted)
		var yaw:=steer*lerpf(1.65,3.8,p.slide)*(1.+instability*.22)
		var assistance:float=smoothstep(35.,130.,p.speed)*lerpf(3.5,.8,p.slide)*(1.-instability*.45)
		var facing:float=wrapf(p.heading,-PI,PI)
		var side_speed:float=strafe*46+Bump.velocity(p)
		var advance:float=p.speed*cos(facing)-side_speed*sin(facing)
		p.heading=wrapf(facing+(yaw-n.curve*advance-sin(facing)*assistance)*dt,-PI,PI)
		var lateral:float=sin(p.heading)*p.speed+side_speed*cos(p.heading)
		# Momentum carries outward as the road turns under a low-grip craft.
		var forward_speed:float=p.speed*cos(p.heading)-side_speed*sin(p.heading)
		p.slip-=n.curve*forward_speed*forward_speed*lerpf(.25,1,p.slide)*(1.+instability*.5)*dt
		var grip:float=lerpf(14,1.8,p.slide)*(1+planted*.75-loose*.48)*(1-p.unload*.35)*(1.-instability*.58)
		p.slip=lerpf(p.slip,lateral,1-exp(-grip*dt))
		var crest_force:float=maxf(0,-n.crest)*forward_speed*forward_speed
		var hold_force:float=230*(1-loose*.82)+planted*180+brake*80
		var launch:=Flight.unload(p,dt,crest_force,hold_force)
		p.x += p.slip * dt
		var edge := lateral_limit(p, n.width)
		if n.get("rails",true) and absf(p.x) > edge and p.lift<2.5:
			var side := signf(p.x)
			p.x = side * edge
			if p.slip * side > 0:
				var hit := absf(p.slip)
				p.energy = maxf(0, p.energy - hit * .10 - 8 * dt)
				p.speed *= 1 - minf(.22, hit * .002)
				p.slip = -side * minf(hit * .4, 40)
				p.heading = -side * .10
				p.flash = .18
		constrain_surface(p,n)
		Track.Recharge.apply(p,n,dt)
		p.distance += (p.speed*cos(p.heading)-side_speed*sin(p.heading))*dt
		update_lap(p)
		var next_node:Dictionary=track.sample(p.distance)
		constrain_surface(p,next_node)
		var next_pose:=Flight.ground_pose(p,next_node,clock)
		var next_velocity:Vector3=(next_pose.origin-previous_pose.origin)/dt
		p.ground_acceleration=(next_velocity-p.ground_velocity)/dt
		p.ground_velocity=next_velocity
		var contact:Dictionary=track.hazards.trace(previous_pose.origin,next_pose.origin)
		if not contact.is_empty() and not p.finished:
			p.air_position=contact.position;p.air_frame=next_pose.basis;p.air_velocity=p.ground_velocity
			Flight.crash(p,contact.normal)
			continue
		var rotation:=Quaternion(previous_pose.basis.inverse()*next_pose.basis).normalized()
		if rotation.w<0: rotation=-rotation
		p.air_rates=(rotation.get_axis()*rotation.get_angle()/dt).limit_length(3.0)
		var over_edge:bool=not next_node.get("rails",true) and not Track.closed_tube(next_node) and absf(p.x)>next_node.width
		if (launch or over_edge or not Track.supported(next_node,p.x)) and not p.finished: Flight.launch(p,next_node,clock)
		if p.energy <= 0:
			p.air_position=next_pose.origin;p.air_frame=next_pose.basis
			Flight.crash(p)
	resolve_contacts()
	weapons.end_step(self,dt)
	for p in racers: refill_energy(p,dt,energy_refill)
	var ordered := standings()
	var all_finished := not racers.is_empty()
	for i in range(ordered.size()):
		ordered[i].rank = i + 1
		all_finished = all_finished and ordered[i].finished
	over = all_finished or clock >= finish_deadline or clock >= 240

static func refill_energy(p:Dictionary,dt:float,rate:float=1.0)->void:
	# The shared shield/boost reserve recovers slowly between bursts and hits.
	if p.energy<p.energy_previous or p.boost>0. or p.warp_time>0. or p.emp_time>0. or p.crashed or p.recovery>0. or p.finished:
		p.energy_refill_delay=ENERGY_REFILL_DELAY
	else:
		var refill_time:=maxf(0.,dt-p.energy_refill_delay)
		p.energy_refill_delay=maxf(0.,p.energy_refill_delay-dt)
		if p.energy>0.: p.energy=minf(100.,p.energy+ENERGY_REFILL_RATE*rate*refill_time)
	p.energy_previous=p.energy

func update_lap(p:Dictionary)->void:
	checkpoints.advance(p,Flight.pose(p,track.sample(p.distance),clock).origin)
	if not checkpoints.complete(p) and p.distance>checkpoints.progress(p)+90.:
		p.checkpoint_missed=true
	var lap:=int(p.distance/track.length)+1
	if lap>p.lap:
		if not checkpoints.complete(p):
			p.checkpoint_missed=true
			p.distance=(p.lap-1)*track.length+fposmod(p.distance,track.length)
			return
		p.best_lap=minf(p.best_lap,clock-p.lap_start)
		p.lap_start=clock
		p.lap=lap
		p.checkpoint_index=0;p.checkpoint_missed=false
		if lap>laps:
			p.finished=true
			p.time=clock-(p.distance-track.length*laps)/maxf(1,p.speed)
			finish_deadline=minf(finish_deadline,clock+25)

static func lateral_limit(p:Dictionary,width:float)->float:
	return width - HULL_HALF_WIDTH*absf(cos(p.heading)) - (HULL_HALF_LENGTH+HULL_CENTER)*absf(sin(p.heading)) - .2

static func constrain_surface(p:Dictionary,n:Dictionary)->void:
	if Track.closed_tube(n):
		p.x=wrapf(p.x,-n.width,n.width)
	elif n.get("rails",true):
		var edge:=lateral_limit(p,n.width)
		p.x=clampf(p.x,-edge,edge)
	var gap:float=n.get("split_gap",0.)
	if gap>.01:
		var route:float=p.get("route",0.)
		if route==0:
			route=signf(p.x) if absf(p.x)>.1 else (1. if p.slot%2==0 else -1.)
			p.route=route
		var margin:float=n.width-lateral_limit(p,n.width)
		margin*=smoothstep(0.,3.,gap)
		if p.x*route<gap+margin:
			p.x=route*(gap+margin)
			if p.slip*route<0: p.slip=-p.slip*.25;p.heading=route*.04
	else: p.route=0.

func contact(a:Dictionary,b:Dictionary)->Vector2:
	var gap:float=fposmod(a.distance-b.distance+track.length*.5,track.length)-track.length*.5
	if absf(gap)>15: return Vector2.ZERO
	var lateral_gap:float=a.x-b.x
	var n:Dictionary=track.sample(a.distance)
	if Track.closed_tube(n): lateral_gap=wrapf(lateral_gap,-n.width,n.width)
	if absf(lateral_gap)>15: return Vector2.ZERO
	var af:=Vector2(sin(a.heading),cos(a.heading))
	var bf:=Vector2(sin(b.heading),cos(b.heading))
	var ar:=Vector2(af.y,-af.x)
	var br:=Vector2(bf.y,-bf.x)
	var delta:=Vector2(lateral_gap,gap)+(af-bf)*HULL_CENTER
	var depth:=INF
	var normal:=Vector2.ZERO
	for axis:Vector2 in [ar,af,br,bf]:
		var extent_a:=HULL_HALF_WIDTH*absf(ar.dot(axis))+HULL_HALF_LENGTH*absf(af.dot(axis))
		var extent_b:=HULL_HALF_WIDTH*absf(br.dot(axis))+HULL_HALF_LENGTH*absf(bf.dot(axis))
		var overlap:=extent_a+extent_b-absf(delta.dot(axis))
		if overlap<=0: return Vector2.ZERO
		if overlap<depth:
			depth=overlap
			var direction:=1.0 if delta.dot(axis)>=0 else -1.0
			normal=axis*direction
	return normal*depth

func resolve_contacts()->void:
	# Iteration keeps a three-wide pack separated even when pinned against a rail.
	for iteration in range(10):
		var touching:=false
		for i in range(racers.size()-1):
			for j in range(i+1,racers.size()):
				var a:=racers[i]
				var b:=racers[j]
				if a.warp_time>0. or b.warp_time>0. or a.finished or b.finished or a.crashed or b.crashed or a.recovery>0 or b.recovery>0 or a.airborne or b.airborne: continue
				var separation:=contact(a,b)
				if separation.length_squared()<.000001: continue
				touching=true
				var normal:=separation.normalized()
				var correction:=separation*.5+normal*.002
				a.x+=correction.x
				b.x-=correction.x
				a.distance+=correction.y
				b.distance-=correction.y
				var av:=Vector2(a.slip,a.speed*cos(a.heading))
				var bv:=Vector2(b.slip,b.speed*cos(b.heading))
				var closing:=(av-bv).dot(normal)
				if closing<0:
					var impulse:=-closing*.55
					av+=normal*impulse
					bv-=normal*impulse
					a.slip=av.x
					b.slip=bv.x
					a.speed=clampf(a.speed+normal.dot(Vector2(sin(a.heading),cos(a.heading)))*impulse,0,440)
					b.speed=clampf(b.speed-normal.dot(Vector2(sin(b.heading),cos(b.heading)))*impulse,0,440)
				Bump.strike(self,a,b,-normal)
				Bump.strike(self,b,a,normal)
		for p in racers:
			if not p.airborne and not p.crashed: constrain_surface(p,track.sample(p.distance))
		if not touching: break

func standings() -> Array:
	var ordered := racers.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.finished != b.finished: return a.finished
		if a.finished: return a.time < b.time
		var ap:float=checkpoints.progress(a);var bp:float=checkpoints.progress(b)
		if ap == bp: return a.slot < b.slot
		return ap > bp)
	return ordered
