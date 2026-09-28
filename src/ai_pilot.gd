extends RefCounted
# Decisions persist for seconds/whole corners; never inject per-frame random input.
# Keep the PRNG state serializable in debug snapshots and independent per pilot.
static func roll(a:Dictionary)->float:
	a.rng=(int(a.rng)*48271)%2147483647
	return float(a.rng)/2147483647.

static func initialize(p:Dictionary,seed_value:int,difficulty:String)->void:
	var a:Dictionary={"rng":1+posmod(seed_value+p.slot*104729,2147483646),"next_plan":0.,"updated":-1.,"line":0.,"line_goal":0.,"pace":1.,"pace_goal":1.,"mode":"race","corner_until":0.,"corner_ready":0.,"corner_quality":0.,"pickup_row":-1.,"pickup_target":0.,"chase_pickup":false,"next_scan":0.,"item_stamp":-1.,"fire_delay":1.,"crash_id":0,"mistakes":0,"great_corners":0,"pickup_chases":0,"pickup_skips":0}
	a.skill=({"easy":.56,"normal":.76,"hard":.9}.get(difficulty,.76))+roll(a)*.09
	a.risk=.2+roll(a)*.65
	a.appetite=.35+roll(a)*.5
	a.side=-1. if roll(a)<.5 else 1.
	p.ai=a

static func update(race:RefCounted,p:Dictionary,n:Dictionary)->void:
	var a:Dictionary=p.ai
	var dt:=clampf(race.clock-a.updated,0.,.1)
	if a.updated==race.clock:return
	a.updated=race.clock
	if a.crash_id!=p.crash_id:
		a.crash_id=p.crash_id;a.corner_until=0.;a.corner_ready=race.clock+8.
		a.mode="recover";a.next_plan=race.clock+3.;a.pace_goal=.94;a.line_goal=0.
	if race.clock>=a.next_plan:
		a.next_plan=race.clock+3.5+roll(a)*5.
		a.mode="attack" if roll(a)<a.risk else "race"
		a.line_goal=(roll(a)*2.-1.)*.27
		a.pace_goal=(1. if a.mode=="attack" else .94)+roll(a)*.06
		a.side=-1. if roll(a)<.5 else 1.
	a.line=move_toward(a.line,a.line_goal,dt*.18)
	a.pace=move_toward(a.pace,a.pace_goal,dt*.06)
	# A single judgement per challenging corner, with time to recover between them.
	if absf(n.curve)>.007 and p.speed>115. and race.clock>=a.corner_ready and p.recovery<=0.:
		a.corner_ready=race.clock+5.+roll(a)*5.
		a.corner_until=race.clock+.8+roll(a)*.7
		var chance:float=(1.-a.skill)*.65+a.risk*.045
		var judgement:=roll(a)
		a.corner_quality=-1. if judgement<chance else (1. if judgement<chance+.24 else 0.)
		if a.corner_quality<0.:a.mistakes+=1
		elif a.corner_quality>0.:a.great_corners+=1
	if p.weapon_acquired!=a.item_stamp:
		a.item_stamp=p.weapon_acquired;a.fire_delay=.45+roll(a)*2.4
	# Scan sparse item rows at 5 Hz, not at physics frequency. Commit to a row
	# once: a player stealing the chosen lane doesn't reroll the decision.
	if race.clock>=a.next_scan:
		a.next_scan=race.clock+.2
		var nearest:=INF
		var row:=-1.
		var lanes:Array[float]=[]
		for item in race.weapons.pickups:
			var ahead:=fposmod(item.distance-p.distance,race.track.length)
			if ahead>260. or item.cooldown>0.:continue
			var absolute:float=p.distance+ahead
			if absolute<nearest-1.:
				nearest=absolute;row=absolute;lanes.clear()
			if absf(absolute-nearest)<1.:lanes.append(item.x)
		if row>=0. and absf(row-a.pickup_row)>1.:
			a.pickup_row=row
			a.chase_pickup=p.weapon.is_empty() and roll(a)<a.appetite
			if a.chase_pickup:
				a.pickup_chases+=1
				a.pickup_target=lanes[mini(int(roll(a)*lanes.size()),lanes.size()-1)]
			else:a.pickup_skips+=1

static func corner_quality(p:Dictionary,clock:float)->float:
	return p.ai.corner_quality if clock<p.ai.corner_until else 0.

static func line(race:RefCounted,p:Dictionary,n:Dictionary)->float:
	var a:Dictionary=p.ai
	var limit:=maxf(0.,n.width-7.)
	var target:float=a.line*n.width
	# Set up outside, then cut towards the apex. Not all drivers take the same line.
	var preview:Dictionary=race.track.sample(p.distance+100.)
	var quality:=corner_quality(p,race.clock)
	if absf(preview.curve)>.003:
		target-=signf(preview.curve)*n.width*(.12+a.risk*.1)
	if absf(n.curve)>.004:
		target+=signf(n.curve)*n.width*(.22+maxf(0.,quality)*.08)
	if quality<0.:target-=signf(n.curve)*n.width*.3
	if n.zone=="repair" and p.energy<55.+a.appetite*30.:
		target=n.width*preload("res://src/track.gd").Recharge.CENTER
	elif a.pickup_row>=p.distance and a.pickup_row-p.distance<240. and p.weapon.is_empty():
		if a.chase_pickup:target=a.pickup_target
		else:target=a.side*n.width*.29 # Between the pickup lanes; keep racing.
	else:
		# Commit to a passing side when catching a car instead of queuing behind it.
		for other in race.racers:
			if other==p or other.crashed or other.airborne or other.finished:continue
			var gap:float=other.distance-p.distance
			if gap>0. and gap<85. and p.speed>other.speed-8. and absf(other.x-target)<10.:
				target=other.x+a.side*12.;break
	return clampf(target,-limit,limit)
