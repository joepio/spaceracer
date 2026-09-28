extends RefCounted
## Rocket-assisted glide payload with a local acquisition area and limited steering.
const Track=preload("res://src/track.gd")
const GRAVITY:=Vector3(0,-14,0)
const TURN_RATE:=1.15 # 66 degrees/sec; strong course correction, still a finite turn radius.
const BOOST_SPEED:=360. # 1296 km/h, below the cruise missile's 1500 km/h.
const BOOST_TIME:=1.25
const BOOST_ACCEL:=200.
const EJECT_SPEED:=55.
const AIM_RADIUS:=150.
const LOCK_RANGE:=1100.
const LOCK_COS:=.573576 # 55 degrees either side of the launch direction.
const PROJECTION_CELL:=192.
const PROXIMITY_RADIUS:=18.
const PREVIEW_STEP:=.24 # Spatial path resolution; the complete path refreshes every tick.
const PREVIEW_STEPS:=25
const RADIUS:=120.
const LIFE:=6.4
const MOUNT:=preload("res://src/racer_design.gd").SOCKET

static func preview_segment(track:RefCounted,point:Vector3)->int:
	# Static coarse centreline index: airborne predictions usually miss the road
	# entirely. Avoid a full-track nearest-point search for every flight sample.
	if not track.has_meta("bomb_projection_cells"):
		var cells:Dictionary={}
		for i in range(0,track.nodes.size(),8):
			var cell:=Vector3i((Vector3(track.nodes[i].p)/PROJECTION_CELL).floor())
			if not cells.has(cell): cells[cell]=[]
			cells[cell].append(i)
		track.set_meta("bomb_projection_cells",cells)
	var cells:Dictionary=track.get_meta("bomb_projection_cells")
	var cell:=Vector3i((point/PROJECTION_CELL).floor())
	var best:=PROJECTION_CELL*PROJECTION_CELL
	var nearest:=-1
	for x in range(-1,2):
		for y in range(-1,2):
			for z in range(-1,2):
				for i in cells.get(cell+Vector3i(x,y,z),[]):
					var distance:=point.distance_squared_to(track.nodes[i].p)
					if distance<best: best=distance;nearest=i
	return nearest

static func contact(track:RefCounted,from:Vector3,to:Vector3,reference:float,estimate:bool=false)->Dictionary:
	var nearest:Dictionary={}
	var best:=INF
	for obstacles in [track.obstacles,track.hazards]:
		if obstacles==null: continue
		var hit:Dictionary=obstacles.trace(from,to,.85)
		if not hit.is_empty() and from.distance_squared_to(hit.position)<best:
			nearest=hit;best=from.distance_squared_to(hit.position)
	# Small swept intervals prevent fast payloads tunnelling through the deck.
	var steps:=1 if estimate else maxi(1,ceili(from.distance_to(to)/4.))
	for i in range(steps):
		var a:=from.lerp(to,float(i)/steps);var b:=from.lerp(to,float(i+1)/steps)
		var midpoint:Vector3=(a+b)*.5
		var hint:=preview_segment(track,midpoint) if estimate else -1
		if estimate and hint<0: continue
		var projected:Dictionary=track.project(midpoint,reference,track.length,hint)
		var n:Dictionary=projected.node
		var lateral:float=projected.lateral
		if not Track.supported(n,lateral): continue
		var surface:=Track.surface_position(n,lateral)
		var normal:=Track.surface_frame(n,lateral).y
		var before:float=(a-surface).dot(normal);var after:float=(b-surface).dot(normal)
		if (before>.85 and after<=.85) or (before<-.85 and after>=-.85):
			var point:=a.lerp(b,(before-signf(before)*.85)/(before-after))
			var distance:=from.distance_squared_to(point)
			if distance<best: nearest={"position":point,"normal":normal};best=distance
	return nearest

static func ready(race:RefCounted,p:Dictionary)->bool:
	return p.weapon=="bomb" and p.airborne and race.weapons.available(p) and not race.over and race.countdown<=0. and p.emp_time<=0. and p.warp_time<=0. and p.drone_time<=0. and not race.weapons.bombs.any(func(b):return b.owner==race.racers.find(p))

static func launch_state(race:RefCounted,p:Dictionary)->Dictionary:
	var frame:Transform3D=race.weapons.pose(race,p)
	var speed:float=p.air_velocity.length()
	var direction:Vector3=p.air_velocity.normalized() if speed>1. else frame.basis.z
	# Nose direction matters, while most of the aircraft's momentum is retained.
	direction=direction.slerp(frame.basis.z,.35).normalized()
	# Pop clear of the dorsal cradle/canopy before beginning the powered glide.
	var velocity:Vector3=direction*minf(BOOST_SPEED,speed+EJECT_SPEED)+frame.basis.y*8.
	return {"position":frame*MOUNT,"velocity":velocity.limit_length(BOOST_SPEED),"owner_clear":false,"owner_blast_clear":false}

static func predict_pilot(race:RefCounted,p:Dictionary,time:float)->Vector3:
	if p.airborne: return p.air_position+p.air_velocity*time
	var node:Dictionary=race.track.sample(p.distance+p.speed*cos(p.heading)*time)
	return Track.point(node,p.x,2.)

static func motor_power(age:float)->float:
	return 1.-smoothstep(BOOST_TIME-.15,BOOST_TIME,age)

static func velocity_step(velocity:Vector3,destination:Vector3,position:Vector3,guided:bool,dt:float,age:float=INF)->Vector3:
	var next:=velocity+GRAVITY*dt
	# Brief launch motor establishes clearance; then coast with aerodynamic drag.
	next*=exp(-.012*dt)
	var burn:=clampf(BOOST_TIME-age,0.,dt)
	if burn>0. and next.length_squared()>1.:
		next=next.normalized()*move_toward(next.length(),BOOST_SPEED,BOOST_ACCEL*burn)
	if guided and next.length_squared()>1.:
		var desired:Vector3=(destination-position).normalized()
		var direction:=next.normalized()
		var angle:=direction.angle_to(desired)
		if angle>.0001: next=direction.slerp(desired,minf(1.,TURN_RATE*dt/angle))*next.length()
	return next.limit_length(BOOST_SPEED)

static func intercept_time(offset:Vector3,velocity:Vector3,speed:float)->float:
	var a:=speed*speed-velocity.length_squared()
	var b:=offset.dot(velocity)
	var discriminant:=b*b+a*offset.length_squared()
	if a>.01 and discriminant>=0.: return clampf((b+sqrt(discriminant))/a,0.,4.)
	return clampf(offset.length()/maxf(80.,speed),0.,4.)

static func preview(race:RefCounted,p:Dictionary)->Dictionary:
	var state:=launch_state(race,p)
	var lock:=acquire(race,p,state)
	var position:Vector3=state.position;var velocity:Vector3=state.velocity
	var points:=PackedVector3Array([position])
	var result:={"position":position,"normal":Vector3.UP,"time":0.,"landed":false,"target":lock.target,"points":points}
	if lock.target>=0:
		# Lock feedback needs the current intercept, not 25 speculative collision
		# sweeps and repeated road-leading simulations per player per physics tick.
		# This is a steering guide; the actual payload still sweeps all collisions.
		result.target_position=lock.position;result.position=lock.position
		result.time=position.distance_to(lock.position)/BOOST_SPEED
		var step_time:=minf(.24,result.time/8.)
		for i in range(8):
			var next:=velocity_step(velocity,lock.position,position,true,step_time,i*step_time)
			position+=(velocity+next)*.5*step_time;velocity=next;points.append(position)
		result.points=points
		return result
	for i in range(PREVIEW_STEPS):
		var next:=velocity_step(velocity,Vector3.ZERO,position,false,PREVIEW_STEP,i*PREVIEW_STEP)
		var to:=position+(velocity+next)*.5*PREVIEW_STEP
		var hit:=contact(race.track,position,to,p.distance,true)
		position=to if hit.is_empty() else Vector3(hit.position)
		velocity=next;points.append(position)
		result.time=(i+1)*PREVIEW_STEP
		if not hit.is_empty():
			result.landed=true;result.normal=hit.get("normal",Vector3.UP);break
	result.position=position;result.points=points
	return result

static func lead_position(race:RefCounted,target:Dictionary,position:Vector3,speed:float,elapsed:float=0.)->Vector3:
	var offset:=predict_pilot(race,target,elapsed)-position
	var velocity:Vector3=target.air_velocity if target.airborne else target.ground_velocity
	var lead:=intercept_time(offset,velocity,speed)
	if not target.airborne:
		for iteration in range(3):
			lead=lerpf(lead,position.distance_to(predict_pilot(race,target,elapsed+lead))/maxf(80.,speed),.65)
	return predict_pilot(race,target,elapsed+lead)

static func acquire(race:RefCounted,p:Dictionary,state:Dictionary)->Dictionary:
	var result:={"target":-1,"position":Vector3.ZERO}
	var forward:Vector3=state.velocity.normalized()
	var best:=INF
	for i in range(race.racers.size()):
		var other:Dictionary=race.racers[i]
		if other==p or not race.weapons.available(other) or other.warp_time>0.: continue
		var current:Vector3=other.air_position if other.airborne else race.weapons.pose(race,other).origin
		var offset:Vector3=current-state.position
		var distance:=offset.length()
		if distance<20. or distance>LOCK_RANGE or forward.dot(offset.normalized())<LOCK_COS: continue
		var predicted:=lead_position(race,other,state.position,BOOST_SPEED)
		if forward.dot((predicted-state.position).normalized())<LOCK_COS: continue
		# Prefer the enemy closest to the aim, with a small distance tie breaker.
		var score:=1.-forward.dot(offset.normalized())+.12*distance/LOCK_RANGE
		if score>=best: continue
		var blocked:=false
		for obstacles in [race.track.obstacles,race.track.hazards]:
			if obstacles!=null and not obstacles.trace(state.position,current,.3).is_empty(): blocked=true;break
		if blocked: continue
		best=score;result.target=i;result.position=predicted
	return result

static func input_step(weapons:RefCounted,race:RefCounted,index:int,fire:bool,dt:float)->void:
	var p:Dictionary=race.racers[index]
	if not ready(race,p):
		p.bomb_armed=false;p.bomb_preview={};return
	p.bomb_armed=true # Preview is automatic whenever the equipped bomb can fire.
	if fire and not p.fire_held:
		weapons.activate(race,index);p.bomb_armed=false;p.bomb_preview={}
	elif p.get("bot",false) and not p.get("view",false):
		p.bomb_preview={} # AI targeting runs through opportunity(), with no HUD simulation.
	else:
		p.bomb_preview=preview(race,p)

static func step(weapons:RefCounted,race:RefCounted,bomb:Dictionary,dt:float)->void:
	bomb.age+=dt
	var previous:Vector3=bomb.position
	var destination:=Vector3.ZERO
	if bomb.target>=0:
		var target:Dictionary=race.racers[bomb.target]
		if not weapons.available(target) or target.warp_time>0.:
			bomb.target=-1
		else:
			var offset:Vector3=weapons.pose(race,target).origin-previous
			# Lose the seeker if the target leaves the forward cone; never reacquire.
			if bomb.velocity.normalized().dot(offset.normalized())<cos(deg_to_rad(85.)):
				bomb.target=-1
			else:
				destination=lead_position(race,target,previous,bomb.velocity.length())
	var next:=velocity_step(bomb.velocity,destination,previous,bomb.target>=0,dt,bomb.age-dt)
	bomb.position+=(bomb.velocity+next)*.5*dt;bomb.velocity=next
	var hit:=contact(race.track,previous,bomb.position,bomb.distance)
	var best:=previous.distance_squared_to(hit.position) if not hit.is_empty() else INF
	var owner_position:Vector3=weapons.pose(race,race.racers[bomb.owner]).origin
	if bomb.age>=.65 and previous.distance_to(owner_position)>20.: bomb.owner_clear=true
	if previous.distance_to(owner_position)>RADIUS+8.: bomb.owner_blast_clear=true
	for i in range(race.racers.size()):
		# Do not arm contact against the launching hull until physically clear.
		# The owner still takes blast damage and can collide after separation.
		if i==bomb.owner and not bomb.get("owner_clear",false): continue
		var p:Dictionary=race.racers[i]
		if not weapons.available(p): continue
		var point:=Geometry3D.get_closest_point_to_segment(weapons.pose(race,p).origin,previous,bomb.position)
		# A close pass of the locked rival triggers the existing blast; precise
		# hull contact is no longer required. Walls still block the swept fuse.
		var fuse:=PROXIMITY_RADIUS if i==bomb.target and bomb.age>.22 else 4.
		if point.distance_to(weapons.pose(race,p).origin)<fuse and previous.distance_squared_to(point)<best:
			hit={"position":point};best=previous.distance_squared_to(point)
	if not hit.is_empty(): detonate(weapons,race,bomb,hit.position)
	elif bomb.age>12.: weapons.bombs.erase(bomb)

static func detonate(weapons:RefCounted,race:RefCounted,bomb:Dictionary,center:Vector3)->void:
	if not weapons.bombs.has(bomb): return
	for p in race.racers:
		# At extreme road-exit speed the aircraft can briefly outrun this slower
		# weapon. Suppress launch self-blast until it has first cleared the owner;
		# returning into the blast after that separation remains dangerous.
		if p==race.racers[bomb.owner] and not bomb.get("owner_blast_clear",false): continue
		var offset:Vector3=weapons.pose(race,p).origin-center
		var strength:=pow(maxf(0.,1.-offset.length()/RADIUS),.65)
		if strength<=0.: continue
		# The owner is vulnerable too: get clear after releasing the payload.
		if not weapons.damage(race,p,145.*strength,1.-.55*strength,center,bomb.owner) or p.crashed: continue
		if p.airborne:
			p.air_velocity+=(offset.normalized()+Vector3.UP*.25)*110.*strength
			p.speed=p.air_velocity.length()
		else:
			var side:=signf(offset.dot(-Track.surface_frame(race.track.sample(p.distance),p.x).x))
			if side==0.: side=1. if p.slot%2==0 else -1.
			p.slip+=side*105.*strength;p.slide=maxf(p.slide,strength);p.slide_hold=maxf(p.slide_hold,strength)
	weapons.bursts.append({"id":bomb.id,"position":center,"life":LIFE,"duration":LIFE,"size":45.})
	weapons.bombs.erase(bomb)

static func opportunity(race:RefCounted,p:Dictionary)->bool:
	if not ready(race,p) or p.fire_held: return false
	if race.clock<float(p.get("bomb_aim_at",-1.)): return false
	p.bomb_aim_at=race.clock+.2
	return acquire(race,p,launch_state(race,p)).target>=0
