extends SceneTree
const Race=preload("res://src/race.gd")
const World=preload("res://src/world.gd")
const Wreck=preload("res://src/wreck.gd")
const Chase=preload("res://src/chase.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var race:=Race.new([{"slot":0}],31,1,"hard","forest")
	race.countdown=0.
	var world:=World.new();root.add_child(world);world.build(race)
	var p:Dictionary=race.racers[0]
	p.distance=220.;p.airborne=true;p.air_time=.5
	var n:Dictionary=race.track.sample(p.distance)
	p.air_position=n.p+n.frame.y*5.;p.air_frame=n.frame
	p.air_velocity=n.frame.z*180.-n.frame.y*45.;p.speed=p.air_velocity.length()
	world.update_ships()
	Race.Flight.crash(p,n.frame.y)
	world.update_ships()
	check(not world.ships[0].visible and world.crashes[0].fragments.size()==16,"Destroyed hull is replaced by 16 recognizable ship components")
	check(p.crash_velocity.length()>180.,"Impact retains pre-crash momentum before HUD speed drops to zero")
	var parts:Array=[]
	for piece in p.wreck.pieces: parts.append({"frame":piece.frame,"half":piece.half})
	var reference:=Wreck.new(parts,p)
	var first:Transform3D=p.wreck.pieces[0].frame
	var fin:Transform3D=world.ships[0].get_node("WingControlL").transform
	for tick in range(180):
		race.step(1./120.,[{"steer":1.,"strafe":-1.,"trim":-1.,"throttle":1.,"brake":1.,"boost":true}])
		reference.step(1./120.,race.track,p.distance)
	world.update_ships()
	check(p.wreck.pieces[0].frame.origin.distance_to(first.origin)>1. and not p.wreck.pieces[0].frame.basis.is_equal_approx(first.basis),"Hull tumbles and travels after impact")
	for i in range(parts.size()):
		check(p.wreck.pieces[i].frame.is_equal_approx(reference.pieces[i].frame),"Controls cannot alter fragment physics")
	check(p.input_steer==0. and p.input_pitch==0. and p.input_strafe==0. and p.input_throttle==0. and p.engine_power==0.,"Wreck ignores steering, pitch, roll, throttle and boost")
	check(world.ships[0].get_node("WingControlL").transform==fin,"Wreck fin pose cannot be controlled")
	var paused:Transform3D=p.wreck.pieces[0].frame
	world.update_ships();world.update_ships()
	check(p.wreck.pieces[0].frame==paused,"Rendering cannot move wrecks while simulation is paused")
	check(p.wreck_wait and p.recovery==0. and p.energy==75.,"Breakup stays visible during recovery delay without repeated damage")
	for tick in range(600): reference.step(1./120.,race.track,p.distance)
	var grounded:=0
	for piece in reference.pieces:
		var road:Dictionary=race.track.project(piece.frame.origin,piece.distance,45.)
		if Race.Track.supported(road.node,road.lateral):
			var height:float=(piece.frame.origin-Race.Track.point(road.node,road.lateral)).dot(road.node.frame.y)
			check(height>=-.1,"Fragments cannot sink through the road")
			if height<6.: grounded+=1
	check(grounded>=5,"Several components land and settle on the road")
	# Swept scenery impact reflects fragment velocity off a thin wall.
	var field=preload("res://src/obstacles.gd").new()
	field.add_box(Transform3D(Basis.IDENTITY,Vector3(0,0,10)),AABB(Vector3(-50,-50,-.1),Vector3(100,100,.2)))
	var contact:Dictionary=field.trace(Vector3.ZERO,Vector3(0,0,30),.5)
	check(not contact.is_empty() and contact.normal.z<-.99 and contact.position.z<10.,"Scenery trace supplies the outward impact normal")
	var body:={"velocity":Vector3(0,0,100),"spin":Vector3.ONE}
	Wreck.bounce(body,contact.normal,1./60.)
	check(body.velocity.z<0.,"Impact impulse rebounds debris instead of tunnelling through the wall")
	var camera:=Camera3D.new();root.add_child(camera)
	var pose:=Transform3D.IDENTITY
	Chase.update(camera,pose,240.,false,0.,true)
	pose.origin.z+=2.
	Chase.update(camera,pose,240.,false,1./120.)
	var before:=camera.transform
	Chase.update_crash(camera,pose.origin,pose.origin,1,1./120.)
	check(camera.position.z>before.origin.z+.5 and camera.position.z<before.origin.z+2.1,"Crash camera carries momentum without snapping to stopped craft")
	check(absf(camera.quaternion.dot(before.basis.get_rotation_quaternion()))>.99,"Crash camera has no abrupt orientation cut")
	for tick in range(180): Chase.update_crash(camera,pose.origin,pose.origin,1,1./120.)
	check(Vector3(camera.get_meta("crash_velocity")).length()<.01 and camera.position.distance_to(before.origin)<23.,"Camera settles within a bounded stopping distance")
	before=camera.transform
	Chase.update_crash(camera,pose.origin,pose.origin+Vector3.UP*10.,1,0.)
	check(before==camera.transform,"Paused crash camera is motionless")
	for tick in range(61): race.step(1./120.,[{}])
	world.update_ships()
	check(not p.crashed and p.wreck==null and world.ships[0].visible and world.crashes[0].fragments.all(func(part):return not part.visible),"Automatic recovery hides pooled fragments and restores the craft")
	world.free();camera.free()
	print("WRECK_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
