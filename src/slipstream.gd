extends RefCounted
## A spatial wake, sampled before any racer moves so every seat gets the same rules.
const RANGE:=145.
const DRAG_REDUCTION:=.26

static func eligible(p:Dictionary)->bool:
	return not p.airborne and not p.crashed and not p.finished and p.recovery<=0. and p.warp_time<=0. and p.emp_time<=0.

static func update(race:RefCounted,dt:float)->void:
	if race.countdown>0. or race.over or race.racers.size()<2:
		for p in race.racers: p.slipstream=0.
		return
	var frames:Array[Transform3D]=[]
	for p in race.racers:
		frames.append(race.Flight.ground_pose(p,race.track.sample(p.distance),race.clock) if eligible(p) else Transform3D.IDENTITY)
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		if not eligible(p):
			p.slipstream=0.
			continue
		var strongest:=0.
		for j in range(race.racers.size()):
			if i==j: continue
			var source:Dictionary=race.racers[j]
			if not eligible(source): continue
			# Wrapped route distance permits drafting lapped cars but rejects nearby
			# unrelated road segments at crossings, splits and stacked loops.
			var gap:=fposmod(source.distance-p.distance,race.track.length)
			if gap<10. or gap>RANGE: continue
			var local:Vector3=frames[j].basis.inverse()*(frames[i].origin-frames[j].origin)
			var behind:float=-local.z
			if behind<10. or behind>RANGE or absf(local.y)>5.: continue
			var alignment:float=frames[i].basis.z.dot(frames[j].basis.z)
			var lateral:=1.-smoothstep(2.,6.+behind*.035,absf(local.x))
			var length_fade:=smoothstep(10.,20.,behind)*(1.-smoothstep(45.,RANGE,behind))
			var speed_fade:=smoothstep(100.,220.,minf(p.speed,source.speed))
			strongest=maxf(strongest,lateral*length_fade*speed_fade*smoothstep(.85,.98,alignment))
		# Build within roughly half a second; briefly carry speed out of the wake.
		# Multiple cars never multiply the benefit.
		p.slipstream=move_toward(p.slipstream,strongest,dt*(2. if strongest>p.slipstream else 3.5))

static func drag_multiplier(p:Dictionary,boosting:bool)->float:
	return 1.-p.slipstream*(.12 if boosting else DRAG_REDUCTION)
