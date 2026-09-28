extends RefCounted
const DURATION:=.24
const COOLDOWN:=.9
const DAMAGE:=14.

static func initialize(p:Dictionary)->void:
	p.merge({"bump_time":0.,"bump_cooldown":0.,"bump_side":0.,"bump_left_held":false,"bump_right_held":false,"bump_hits":{},"bump_guard":0.},true)

static func begin(p:Dictionary,input:Dictionary,dt:float,countdown:float)->void:
	p.bump_time=maxf(0.,p.bump_time-dt)
	p.bump_cooldown=maxf(0.,p.bump_cooldown-dt)
	p.bump_guard=maxf(0.,p.bump_guard-dt)
	var left:bool=input.get("left",false)
	var right:bool=input.get("right",false)
	var side:=float(int(right and not p.bump_right_held)-int(left and not p.bump_left_held))
	p.bump_left_held=left;p.bump_right_held=right
	var available:bool=not p.crashed and not p.finished and not p.airborne and p.recovery<=0. and p.warp_time<=0. and p.emp_time<=0.
	if not available: p.bump_time=0.
	if not available or countdown>0. or p.bump_cooldown>0. or side==0. or (left and right): return
	p.bump_side=side;p.bump_time=DURATION;p.bump_cooldown=COOLDOWN;p.bump_hits.clear()

static func velocity(p:Dictionary)->float:
	if p.bump_time<=0.: return 0.
	return p.bump_side*sin((1.-p.bump_time/DURATION)*PI)*85.

static func strike(race:RefCounted,attacker:Dictionary,target:Dictionary,toward:Vector2)->void:
	if not race.weapons.available(attacker) or not race.weapons.available(target): return
	if attacker.bump_time<=0. or attacker.bump_hits.has(target.slot) or target.bump_guard>0.: return
	var direction:Vector2=Vector2(cos(attacker.heading),-sin(attacker.heading))*attacker.bump_side
	if direction.dot(toward)<.55: return # Front/rear contact is not a side attack.
	attacker.bump_hits[target.slot]=true
	if race.weapons.damage(race,target,DAMAGE,.97,race.weapons.pose(race,attacker).origin,race.racers.find(attacker)):
		target.bump_guard=.3
		if not target.crashed:
			target.slip+=direction.x*28.
			target.speed=clampf(target.speed+direction.y*28.,0.,440.)
