extends SceneTree
const Race=preload("res://src/race.gd")
const Field=preload("res://src/obstacles.gd")
const Vfx=preload("res://src/crash_vfx.gd")
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var field:=Field.new()
	field.add_box(Transform3D(Basis.IDENTITY.scaled(Vector3(10,100,.3)),Vector3(0,0,50)))
	check(field.hit(Vector3.ZERO,Vector3(0,0,200))!=null,"Swept hull catches thin objects without tunnelling")
	check(field.hit(Vector3(30,0,0),Vector3(30,0,200))==null,"Empty space beside geometry remains flyable")
	var rotated:=Field.new()
	rotated.add_box(Transform3D(Basis(Vector3.UP,PI*.25).scaled(Vector3(4,20,80)),Vector3.ZERO))
	check(rotated.hit(Vector3(-26,0,-26),Vector3(-25,0,-25),.1)==null,"Rotated shapes do not collide with their empty world-bounds corners")
	var race:=Race.new([{"slot":0}],31,1,"normal")
	race.countdown=0.
	var p:Dictionary=race.racers[0]
	p.distance=500.;p.airborne=true;p.air_time=.5;p.air_entry_speed=235.;p.energy=100.
	var n:Dictionary=race.track.sample(500.)
	p.air_position=n.p+n.frame.y*80.;p.air_frame=n.frame;p.air_velocity=n.frame.z*235.
	race.track.obstacles=Field.new()
	race.track.obstacles.add_box(Transform3D(n.frame.scaled(Vector3(25,25,1)),p.air_position+n.frame.z*20.))
	race.step(.15,[{"throttle":1.}])
	check(p.crashed and p.wreck_wait and p.recovery==0 and p.energy==75.,"Scenery impact creates a paid wreck before automatic recovery")
	var impact:Vector3=p.air_position
	var id:int=p.crash_id
	for tick in range(120): race.step(1./120.,[{}])
	check(p.air_position==impact and p.crash_id==id and p.wreck_wait,"Explosion remains at impact during the first second without repeating")
	var passing:Dictionary=Race.new([{"slot":1}],31).racers[0]
	passing.distance=p.distance;passing.x=p.x
	race.racers.append(passing)
	var saved_distance:float=p.distance
	race.resolve_contacts()
	check(p.distance==saved_distance and passing.distance==saved_distance,"Off-track wreck cannot create phantom contacts at its takeoff position")
	race.racers.pop_back()
	var effect:=Vfx.new();root.add_child(effect)
	effect.update(p,0.);effect.update(p,.2)
	var debris:Transform3D=effect.debris.get_instance_transform(0)
	check(effect.visible and effect.flash.light_energy>0.,"Impact displays debris and a short light flash")
	effect.update(p,.2)
	check(effect.debris.get_instance_transform(0)==debris,"Paused clock freezes explosion motion")
	check(not race.can_reset(p),"Wreck hides the manual-reset prompt and touch button")
	race.step(.5,[{"reset":true}])
	check(p.crashed and p.wreck_time<2.,"Y cannot skip or restart the automatic wreck delay")
	race.step(.51,[{}])
	check(not p.crashed and not p.wreck_wait and p.recovery==0 and p.energy==75.,"Crash returns to track automatically after two seconds without charging twice")
	check(p.distance<=500. and Race.Track.supported(race.track.sample(p.distance),p.x),"Recovery cannot advance race progress")
	check(p.speed==90. and p.weapon_guard==2. and p.crash_id==id,"Automatic recovery restores momentum and protection without another explosion")
	effect.update(p,race.vfx_clock)
	check(effect.debris.visible_instance_count==0 and effect.blast.visible,"Recovery hides debris while the impact smoke finishes fading")
	effect.update(p,4.)
	check(not effect.visible,"Explosion fully expires after its smoke tail")
	effect.queue_free()
	# Two racers recover independently; a depleted hull gets the existing reserve.
	var pair:=Race.new([{"slot":2},{"slot":7}],31,1,"hard")
	pair.countdown=0.
	var depleted:Dictionary=pair.racers[0]
	depleted.distance=pair.track.jumps[0].takeoff+10.;depleted.energy=0.
	Race.Flight.crash(depleted)
	pair.step(1.,[{},{}])
	Race.Flight.crash(pair.racers[1])
	pair.step(1.01,[{},{}])
	check(not depleted.crashed and depleted.energy==25.,"Empty shields automatically rebuild with a survival reserve")
	check(pair.racers[1].crashed,"Each racer has its own crash timer")
	check(depleted.distance<pair.track.jumps[0].takeoff and Race.Track.supported(pair.track.sample(depleted.distance),depleted.x,5.8),"Missed jump automatically recovers to supported approach road")
	pair.step(1.01,[{},{}])
	check(not pair.racers[1].crashed and pair.racers[1].energy==75.,"Second racer recovers on its own schedule without a reset press")
	# Fast response and reduced cruise, while launch momentum has time to settle.
	var flyer:=Race.new([{"slot":0}],31).racers[0]
	flyer.air_velocity=Vector3(0,0,390);flyer.air_entry_speed=390.;flyer.air_frame=Basis.IDENTITY
	Race.Flight.integrate_air(flyer,.05,1.,1.,1.,0.)
	check(flyer.air_rates.z>2.5 and absf(flyer.air_rates.y)>1.,"Air controls reach strong roll and yaw rates within 50 ms")
	check(flyer.speed>300.,"Boost launch momentum is not cut instantly")
	for tick in range(600):
		flyer.air_time+=1./120.;Race.Flight.integrate_air(flyer,1./120.,0.,0.,1.,0.)
	check(flyer.speed<=235.01 and flyer.speed<Race.TOP_SPEED,"Sustained flight is slower than unboosted driving, including dives")
	for seed_value in [6,31,145,421]:
		var normal:=Race.Track.new(seed_value,"normal")
		var hard:=Race.Track.new(seed_value,"hard")
		var peak_n:=0.;var peak_h:=0.;var bank_step:=0.
		for node in normal.nodes:
			if not node.loop: peak_n=maxf(peak_n,absf(node.curve))
		for i in range(hard.nodes.size()):
			var node:Dictionary=hard.nodes[i]
			if not node.loop: peak_h=maxf(peak_h,absf(node.curve))
			bank_step=maxf(bank_step,absf(node.bank-hard.nodes[(i+1)%hard.nodes.size()].bank))
		check(peak_h>peak_n*1.3,"Hard contains materially tighter corners")
		check(bank_step<.045,"Bank angle changes smoothly between adjacent road segments")
		var open_n:int=normal.nodes.filter(func(node):return not node.rails and not node.air_gap).size()
		var open_h:int=hard.nodes.filter(func(node):return not node.rails and not node.air_gap).size()
		check(float(open_h)/hard.nodes.size()>float(open_n)/normal.nodes.size()+.05,"Hard has more genuinely unguarded road")
		for jump in hard.jumps:
			var lip:Dictionary=hard.sample(jump.takeoff)
			var deck:Dictionary=hard.sample(jump.landing+20.)
			var sideways:float=absf((deck.p-lip.p).dot(lip.frame.x))
			check(sideways>deck.width-5.,"Hard landing cannot be reached by simply coasting straight")
		print("HARD_METRICS seed=",seed_value," curvature=",peak_h," normal=",peak_n," bank_step=",bank_step," open=",float(open_h)/hard.nodes.size())
	# The same steering controller must fail this technical corner at full speed
	# and complete it cleanly when allowed to brake before the apex.
	for braking in [false,true]:
		var corner:=Race.new([{"slot":0}],31,1,"hard")
		var peak:=0.;var apex:=0.
		for i in range(corner.track.nodes.size()):
			var node:Dictionary=corner.track.nodes[i]
			if node.u>.38 and node.u<.48 and absf(node.curve)>peak:
				peak=absf(node.curve);apex=i*corner.track.step
		var driver:Dictionary=corner.racers[0]
		driver.distance=apex-230.;driver.speed=265.;driver.x=0.;corner.countdown=0.
		var departed:=false
		for tick in range(1200):
			var input:Dictionary=corner.bot(driver)
			if not braking: input.brake=0.
			corner.step(1./120.,[input])
			if driver.airborne or driver.crashed: departed=true;break
			if driver.distance>apex+230.: break
		check(not departed and driver.distance>apex+230. and driver.energy==100. if braking else departed,"Hard technical corner rewards braking and punishes full-throttle steering alone")
	print("CRASH_TESTS ",checks," checks, ",failures," failures")
	await process_frame
	quit(1 if failures else 0)
