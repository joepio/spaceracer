extends SceneTree
const Race=preload("res://src/race.gd")
const Ship=preload("res://src/ship.gd")
const Chase=preload("res://src/chase.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var race:=Race.new([{"slot":0}],31);race.countdown=0.
	var p:Dictionary=race.racers[0];p.distance=900.;p.startup=1.
	var n:Dictionary=race.track.sample(p.distance)
	p.airborne=true;p.air_frame=n.frame;p.air_position=Race.Track.point(n,250.,95.);p.air_velocity=n.frame.z*210.
	var camera:=Camera3D.new();root.add_child(camera)
	Chase.update(camera,Transform3D(p.air_frame,p.air_position),210.,false,.01,true)
	camera.set_meta("chase_velocity",n.frame.z*180.)
	var original:=camera.transform
	Race.Flight.crash(p)
	var target:=race.respawn_target(p)
	var stable:Transform3D=target.pose
	for tick in range(240):
		race.step(1./120.,[{}])
		if p.crashed: Chase.update_respawn(camera,target.pose,p.crash_id,p.wreck_time,2.,1./120.)
		if tick==120:
			check(camera.position.distance_to(original.origin)>60.,"Camera travels toward respawn while wreck still exists")
			var frozen:=camera.transform
			Chase.update_respawn(camera,target.pose,p.crash_id,p.wreck_time,2.,0.)
			check(camera.transform==frozen,"Pause freezes the camera transfer")
	for tick in range(2):
		if p.crashed: race.step(1./120.,[{}])
	check(not p.crashed and p.rebuild_time>0.,"Respawn starts reconstruction without extending the recovery delay")
	check(is_equal_approx(p.distance,float(target.distance)) and is_equal_approx(p.x,float(target.x)),"Respawn and camera share the exact destination")
	var before:=camera.transform
	Chase.update(camera,Race.Flight.pose(p,race.track.sample(p.distance),race.clock),p.speed,false,1./120.,false,0.,false)
	check(camera.position.distance_to(before.origin)<.1,"Normal chase resumes without a position snap")
	var ship:=Ship.build(Color.RED);root.add_child(ship);ship.transform=stable
	p.rebuild_time=.5;Ship.Rebuild.update(ship,p)
	check(ship.get_meta("rebuild_light").visible and ship.get_meta("rebuild_light").light_energy>0.,"Reconstruction emits local light")
	check(ship.get_meta("rebuild_meshes").all(func(mesh):return mesh.material_overlay!=null),"Every hull component gets the holographic scan")
	var progress:float=ship.get_meta("rebuild_material").get_shader_parameter("progress")
	Ship.Rebuild.update(ship,p)
	check(is_equal_approx(progress,float(ship.get_meta("rebuild_material").get_shader_parameter("progress"))),"Reconstruction freezes while simulation is paused")
	p.rebuild_time=0.;Ship.Rebuild.update(ship,p)
	check(not ship.get_meta("rebuild_light").visible and ship.get_meta("rebuild_meshes").all(func(mesh):return mesh.material_overlay==null),"All extra rendering and light disappear after reconstruction")
	check(ship.get_meta("damage_materials").all(func(mat):return mat.get_shader_parameter("rebuild_progress")==1.),"Paint returns to normal without clipping")
	# A fresh crash invalidates the cached destination and uses a safe deck.
	p.distance=race.track.jumps[0].takeoff+5.;p.crash_id+=1;p.checkpoint_missed=false
	var jump_target:=race.respawn_target(p)
	check(is_equal_approx(float(jump_target.distance),race.track.safe_respawn(p.distance)),"Camera targets the safe ramp approach instead of a jump gap")
	p.crash_id+=1;p.checkpoint_missed=true
	var checkpoint_target:=race.respawn_target(p)
	check(is_equal_approx(float(checkpoint_target.distance),race.track.safe_respawn(race.checkpoints.return_distance(p))),"Missed checkpoint return is resolved before camera travel")
	p.rebuild_time=.4;p.crashed=true;Ship.Rebuild.update(ship,p)
	check(not ship.get_meta("rebuild_light").visible,"A second crash cancels reconstruction immediately")
	print("RESPAWN_PRESENTATION_TESTS ",checks," checks, ",failures," failures")
	ship.queue_free();camera.queue_free();await process_frame;quit(1 if failures else 0)
