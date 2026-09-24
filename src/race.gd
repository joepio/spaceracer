extends RefCounted
const Track = preload("res://src/track.gd")
const Flight=preload("res://src/flight.gd")
const TOP_SPEED := 265.0
const BOOST_SPEED := 390.0
# Full visible hull, including swept wings; local nose is slightly ahead of origin.
const HULL_HALF_WIDTH := 4.7
const HULL_HALF_LENGTH := 4.45
const HULL_CENTER := .65
var track: RefCounted
var racers: Array[Dictionary] = []
var countdown := 3.0
var clock := 0.0
var laps := 3
var over := false
var finish_deadline := INF

func _init(roster: Array, track_seed: int, lap_count: int = 3) -> void:
	track = Track.new(track_seed)
	laps = lap_count
	for i in range(roster.size()):
		var p: Dictionary = roster[i].duplicate(true)
		p.merge({"distance": -floorf(i / 3.0) * 13.0, "x": (i % 3 - (mini(3, roster.size()) - 1) / 2.0) * 12.0, "speed": 0.0,
			"heading": 0.0, "slip": 0.0, "energy": 100.0, "boost": 0.0, "boost_held": false,
			"input_steer":0.0,"input_strafe":0.0,"input_pitch":0.0,"input_brake":0.0,"air_position":Vector3.ZERO,"air_velocity":Vector3.ZERO,"air_frame":Basis.IDENTITY,
			"air_time":0.0,"air_travel":0.0,"air_roll":0.0,"launch_charge":0.0,"launch_cooldown":0.0,"crashed":false,"trim": 0.0, "lift": 0.0, "lift_speed": 0.0, "airborne": false, "slide": 0.0, "braking": 0.0, "thrust": 0.0, "flash": 0.0, "recovery": 0.0, "lap": 1, "rank": i + 1, "finished": false,
			"time": INF, "best_lap": INF, "lap_start": 0.0, "drifting": false, "on_pad": false}, true)
		racers.append(p)

func bot(p: Dictionary) -> Dictionary:
	var n:Dictionary=track.sample(p.distance)
	var peak:=absf(n.curve)
	var safe_speed:=TOP_SPEED
	# Brake before the apex, using available stopping distance rather than a late threshold.
	for ahead in [30.0,65.0,110.0,165.0]:
		var upcoming:Dictionary=track.sample(p.distance+ahead)
		var bend:=absf(upcoming.curve)
		peak=maxf(peak,bend)
		var corner_speed:=clampf(1.65/maxf(.001,bend),125,TOP_SPEED)
		safe_speed=minf(safe_speed,sqrt(corner_speed*corner_speed+2*150*ahead))
	var brake:=clampf((p.speed-safe_speed)/35.0,0,1)
	if absf(n.curve)>.006 and p.speed>145: brake=maxf(brake,.48)
	var target:float=-n.width*.63 if n.zone=="repair" and p.energy<85 else sin(p.slot*2)*4
	var slide:float=p.slide
	var grip:=lerpf(14,2.8,slide)
	var inertia:=lerpf(.25,1,slide)
	var desired_lateral:=clampf((target-p.x)*2.4,-45,45)
	var desired_heading:=asin(clampf((desired_lateral+n.curve*p.speed*p.speed*inertia/grip)/maxf(p.speed,60),-.75,.75))
	var turn:=clampf((n.curve*p.speed+desired_heading*lerpf(3.5,1.2,slide)+(desired_heading-p.heading)*3.8+(desired_lateral-p.slip)*.012)/lerpf(1.65,3.8,slide),-1,1)
	return {"steer":turn,"throttle":1.0,"brake":brake,"left":false,"right":false,
		"boost":p.lap>1 and p.energy>40 and peak<.0025 and p.boost==0 and brake<.05}

func step(dt: float, inputs: Array) -> void:
	if over:
		return
	for i in range(racers.size()):
		var input:Dictionary=inputs[i]
		racers[i].input_steer=clampf(input.get("steer",0.0),-1,1)
		racers[i].input_pitch=clampf(input.get("trim",0.0),-1,1)
		racers[i].input_strafe=clampf(float(input.get("strafe",0.0))+int(input.get("right",false))-int(input.get("left",false)),-1,1)
		racers[i].input_brake=clampf(float(input.get("brake",0.0)),0,1)
	if countdown > 0:
		countdown = maxf(0, countdown - dt)
		return
	clock += dt
	for i in range(racers.size()):
		var p := racers[i]
		var c: Dictionary = inputs[i]
		p.flash = maxf(0, p.flash - dt)
		p.launch_cooldown=maxf(0,p.launch_cooldown-dt)
		if p.finished:
			continue
		var n: Dictionary = track.sample(p.distance)
		var steer := clampf(c.get("steer", 0), -1, 1)
		var throttle := clampf(c.get("throttle", 0), 0, 1)
		var brake:=clampf(float(c.get("brake",0.0)),0,1)
		p.braking=brake
		p.thrust=throttle*(1-brake) if p.recovery==0 else 0.0
		var strafe:=clampf(float(c.get("strafe",0.0))+int(c.get("right",false))-int(c.get("left",false)),-1,1)
		p.trim=move_toward(p.trim,clampf(float(c.get("trim",0.0)),-1,1),dt*5)
		var planted:float=maxf(0,p.trim)
		var loose:float=maxf(0,-p.trim)
		# LT progressively releases magnetic grip; momentum and hull heading separate.
		var slide_target:=brake*smoothstep(45,140,p.speed)*(1-planted*.55)
		p.slide=move_toward(p.slide,slide_target,dt*(5.0 if slide_target>p.slide else 2.4))
		p.drifting=p.slide>.18
		if c.get("boost", false) and not p.boost_held and p.lap > 1 and p.energy > 22 and p.recovery == 0 and brake<.05 and not p.airborne:
			p.energy -= 22
			p.boost = 1.25
		p.boost_held = c.get("boost", false)
		p.boost = maxf(0, p.boost - dt)
		if p.recovery > 0:
			p.recovery = maxf(0, p.recovery - dt)
			p.speed = 0.0
			p.slide = 0.0
			p.lift = 0.0
			p.lift_speed = 0.0
			p.airborne = false
			if p.recovery == 0:
				p.crashed=false
				p.launch_charge=0.0
				p.launch_cooldown=1.0
				p.energy = 65.0
				p.x = 0.0
				p.heading = 0.0
				p.slip = 0.0
				p.speed = 90.0
			continue
		if p.airborne:
			Flight.step(p,track,dt,steer,strafe,throttle,brake)
			if not p.airborne and p.recovery==0: update_lap(p)
			continue
		p.on_pad = n.zone == "boost" and absf(p.x) < n.width * .35 and brake<.05 and p.lift<1
		var fast: bool = (p.boost > 0 or p.on_pad) and brake<.05
		var target:float=(BOOST_SPEED if fast else TOP_SPEED)+loose*60-planted*35
		var acceleration: float = throttle * (1-brake*.9) * 125 * (1 - pow(p.speed / target, 2))
		if fast:
			acceleration += maxf(0, target - p.speed) * 3
		if throttle == 0:
			acceleration -= 38
		acceleration -= 240*brake+planted*p.speed*.12
		acceleration -= absf(steer) * p.speed * lerpf(.045,.08,p.slide) + n.slope * 28
		p.speed = clampf(p.speed + acceleration * dt, 0, 440)
		var yaw:=steer*lerpf(1.65,3.8,p.slide)*(.35+.65*minf(p.speed/120,1))*(.45 if p.airborne else 1.0)
		p.heading=clampf(p.heading+(yaw-n.curve*p.speed-p.heading*lerpf(3.5,1.2,p.slide))*dt,-1.05,1.05)
		var lateral:float=sin(p.heading)*p.speed+strafe*46*(.35 if p.airborne else 1.0)
		# Momentum carries outward as the road turns under a low-grip craft.
		var forward_speed:float=p.speed*maxf(.55,cos(p.heading))
		p.slip-=n.curve*forward_speed*forward_speed*lerpf(.25,1,p.slide)*dt
		var grip:float=lerpf(14,2.8,p.slide)*(1+planted*.75-loose*.48)*(.18 if p.airborne else 1.0)
		p.slip=lerpf(p.slip,lateral,1-exp(-grip*dt))
		var crest_force:float=maxf(0,-n.crest)*forward_speed*forward_speed
		var hold_force:float=230*(1-loose*.82)+planted*180+brake*80
		var full_pull:bool=loose>.90 and p.speed>165 and brake<.10
		p.launch_charge=p.launch_charge+dt if full_pull else 0.0
		var crest_launch:bool=loose>.35 and p.speed>260 and crest_force>hold_force+38
		var launch:bool=p.launch_cooldown==0 and (p.launch_charge>.25 or crest_launch)
		p.x += p.slip * dt
		var edge := lateral_limit(p, n.width)
		if absf(p.x) > edge and p.lift<2.5:
			var side := signf(p.x)
			p.x = side * edge
			if p.slip * side > 0:
				var hit := absf(p.slip)
				p.energy = maxf(0, p.energy - hit * .10 - 8 * dt)
				p.speed *= 1 - minf(.22, hit * .002)
				p.slip = -side * minf(hit * .4, 40)
				p.heading = -side * .10
				p.flash = .18
		if n.zone == "repair" and p.x < -n.width * .35 and p.lift<1:
			p.energy = minf(100, p.energy + 34 * dt)
		p.distance += p.speed * maxf(.55, cos(p.heading)) * dt
		update_lap(p)
		if launch and not p.finished: Flight.launch(p,track.sample(p.distance))
		if p.energy <= 0:
			p.recovery = 2.0
			p.boost = 0.0
	resolve_contacts()
	var ordered := standings()
	var all_finished := not racers.is_empty()
	for i in range(ordered.size()):
		ordered[i].rank = i + 1
		all_finished = all_finished and ordered[i].finished
	over = all_finished or clock >= finish_deadline or clock >= 240

func update_lap(p:Dictionary)->void:
	var lap:=int(p.distance/track.length)+1
	if lap>p.lap:
		p.best_lap=minf(p.best_lap,clock-p.lap_start)
		p.lap_start=clock
		p.lap=lap
		if lap>laps:
			p.finished=true
			p.time=clock-(p.distance-track.length*laps)/maxf(1,p.speed)
			finish_deadline=minf(finish_deadline,clock+25)

static func lateral_limit(p:Dictionary,width:float)->float:
	return width - HULL_HALF_WIDTH*absf(cos(p.heading)) - (HULL_HALF_LENGTH+HULL_CENTER)*absf(sin(p.heading)) - .2

func contact(a:Dictionary,b:Dictionary)->Vector2:
	var gap:float=fposmod(a.distance-b.distance+track.length*.5,track.length)-track.length*.5
	if absf(gap)>15 or absf(a.x-b.x)>15: return Vector2.ZERO
	var af:=Vector2(sin(a.heading),cos(a.heading))
	var bf:=Vector2(sin(b.heading),cos(b.heading))
	var ar:=Vector2(af.y,-af.x)
	var br:=Vector2(bf.y,-bf.x)
	var delta:=Vector2(a.x-b.x,gap)+(af-bf)*HULL_CENTER
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
				if a.finished or b.finished or a.recovery>0 or b.recovery>0 or a.airborne or b.airborne: continue
				var separation:=contact(a,b)
				if separation.length_squared()<.000001: continue
				touching=true
				var normal:=separation.normalized()
				var correction:=separation*.5+normal*.002
				a.x+=correction.x
				b.x-=correction.x
				a.distance+=correction.y
				b.distance-=correction.y
				var av:=Vector2(a.slip,a.speed*maxf(.55,cos(a.heading)))
				var bv:=Vector2(b.slip,b.speed*maxf(.55,cos(b.heading)))
				var closing:=(av-bv).dot(normal)
				if closing<0:
					var impulse:=-closing*.55
					av+=normal*impulse
					bv-=normal*impulse
					a.slip=av.x
					b.slip=bv.x
					a.speed=clampf(av.y/maxf(.55,cos(a.heading)),0,440)
					b.speed=clampf(bv.y/maxf(.55,cos(b.heading)),0,440)
		for p in racers:
			var edge:=lateral_limit(p,track.sample(p.distance).width)
			if not p.airborne: p.x=clampf(p.x,-edge,edge)
		if not touching: break

func standings() -> Array:
	var ordered := racers.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.finished != b.finished: return a.finished
		if a.finished: return a.time < b.time
		if a.distance == b.distance: return a.slot < b.slot
		return a.distance > b.distance)
	return ordered
