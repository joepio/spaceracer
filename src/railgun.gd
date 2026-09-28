extends RefCounted
## One straight hitscan round with a camera-matched aim-assist circle.
const Obstacles=preload("res://src/obstacles.gd")
const Contact=preload("res://src/dive_bomb.gd")
const RANGE:=650.
const DAMAGE:=50.
const LIFE:=.32
const MOUNT:=preload("res://src/racer_design.gd").SOCKET
const MUZZLE:=MOUNT+Vector3(0,.32,3.7)
const GUIDE_RADIUS:=.11 # Fraction of each player's viewport height.
const AIM_TANGENT:=.14 # Equivalent cone for AI / headless play.

static func view_context(race:RefCounted,index:int,camera:Camera3D)->Dictionary:
	var frame:Transform3D=race.weapons.pose(race,race.racers[index])
	var ahead:=frame*MUZZLE+frame.basis.z*200.
	if camera.is_position_behind(ahead): return {}
	var center:=camera.unproject_position(ahead)
	var radius:=float(camera.get_viewport().size.y)*GUIDE_RADIUS
	var inverse:=camera.global_transform.affine_inverse()
	var local:Vector3=inverse*camera.project_position(center,100.)
	var edge:Vector3=inverse*camera.project_position(center+Vector2(radius,0),100.)
	return {"inverse":inverse,"center":Vector2(local.x,local.y)/100.,"radius":local.distance_to(edge)/100.,"screen":center,"pixels":radius}

static func aim_error(frame:Transform3D,point:Vector3,view:Dictionary)->float:
	if not view.is_empty():
		var local:Vector3=view.inverse*point
		if local.z>=-.01: return INF
		return (Vector2(local.x,local.y)/-local.z-view.center).length()/view.radius
	var offset:=frame.basis.inverse()*(point-frame*MUZZLE)
	if offset.z<=.01: return INF
	return Vector2(offset.x,offset.y).length()/(offset.z*AIM_TANGENT)

static func ready(race:RefCounted,p:Dictionary)->bool:
	return p.weapon=="railgun" and race.weapons.available(p) and not race.over and race.countdown<=0. and p.emp_time<=0. and p.warp_time<=0. and p.drone_time<=0.

static func input_step(weapons:RefCounted,race:RefCounted,index:int,fire:bool,_dt:float)->void:
	var p:Dictionary=race.racers[index]
	if not ready(race,p):
		p.rail_armed=false;p.rail_preview={};return
	if not p.rail_armed or p.get("rail_stamp",-1.)!=p.weapon_acquired:
		p.rail_preview_at=-1.;p.rail_stamp=p.weapon_acquired
	p.rail_armed=true
	if fire and not p.fire_held:
		weapons.activate(race,index);p.rail_armed=false;p.rail_preview={}
	elif race.clock>=p.get("rail_preview_at",-1.):
		# Cached collision-aware indicator; firing always traces the current aim.
		var candidate:=trace(race,index,false)
		p.rail_preview=trace(race,index) if candidate.target>=0 else candidate
		p.rail_preview_at=race.clock+.075

static func trace(race:RefCounted,index:int,scenery:bool=true)->Dictionary:
	var p:Dictionary=race.racers[index]
	var frame:Transform3D=race.weapons.pose(race,p)
	var origin:=frame*MUZZLE
	var end:=origin+frame.basis.z.normalized()*RANGE
	var target:=-1
	var blocked:=false
	var error:=1.000001
	var aim:Dictionary=p.get("rail_view",{})
	# Snap only within the displayed circle, then trace a straight shot to it.
	for i in range(race.racers.size()):
		var other:Dictionary=race.racers[i]
		if i==index or not race.weapons.available(other) or other.warp_time>0. or other.weapon_guard>0.: continue
		var point:Vector3=race.weapons.pose(race,other)*Vector3(0,.6,0)
		if origin.distance_to(point)>RANGE or (point-origin).dot(frame.basis.z)<=0.: continue
		var candidate:=aim_error(frame,point,aim)
		if candidate<error:
			error=candidate;end=point
	var closest:=origin.distance_squared_to(end)
	for i in range(race.racers.size()):
		var other:Dictionary=race.racers[i]
		if i==index or not race.weapons.available(other): continue
		var body:Transform3D=race.weapons.pose(race,other)
		var hit:=Obstacles.box_contact(body.affine_inverse(),AABB(Vector3(-4.5,-.7,-4.),Vector3(9.,2.8,8.)),origin,end)
		if hit.is_empty(): continue
		var distance:=origin.distance_squared_to(hit.position)
		if distance<closest:
			closest=distance;end=hit.position;target=i if other.warp_time<=0. and other.weapon_guard<=0. else -1;blocked=true
	# Trace only as far as the nearest vehicle; most shots are short-range.
	if scenery:
		var wall:=Contact.contact(race.track,origin,end,p.distance)
		if not wall.is_empty() and origin.distance_squared_to(wall.position)<closest:
			end=wall.position;blocked=true;target=-1
	return {"from":origin,"to":end,"target":target,"contact":blocked,"basis":frame.basis}

static func fire(weapons:RefCounted,race:RefCounted,index:int)->void:
	var shot:=trace(race,index)
	if shot.target>=0: weapons.damage(race,race.racers[shot.target],DAMAGE,.90,shot.from,index)
	weapons.serial+=1
	shot.id=weapons.serial;shot.life=LIFE
	weapons.rail_shots.append(shot)
	# Also bound allocations when dev keys equip a new shot every frame.
	while weapons.rail_shots.size()>12: weapons.rail_shots.pop_front()

static func opportunity(race:RefCounted,p:Dictionary)->bool:
	if p.weapon!="railgun" or p.fire_held: return false
	if race.clock<float(p.get("rail_aim_at",-1.)): return false
	p.rail_aim_at=race.clock+.16
	# Cheap vehicle-only aim test first; actual firing traces road and scenery.
	var index:int=race.racers.find(p)
	if trace(race,index,false).target<0: return false
	return trace(race,index).target>=0
