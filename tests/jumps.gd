extends SceneTree
const Race=preload("res://src/race.gd")
const Track=preload("res://src/track.gd")
const Flight=preload("res://src/flight.gd")
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<25: push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	for difficulty in Track.DIFFICULTIES:
		for seed_value in range(1,41)+[42,145,421,99999]:
			var race:=Race.new([{"slot":0}],seed_value,1,difficulty)
			var track:RefCounted=race.track
			var repeat:=Track.new(seed_value,difficulty)
			check(track.nodes==repeat.nodes,"Seed and difficulty reproduce the exact track")
			if difficulty=="easy":
				check(track.jumps.is_empty(),"Easy has no mandatory flight")
				check(track.nodes.all(func(n):return n.rails and not n.air_gap),"Easy protects every open edge")
				continue
			for jump in track.jumps:
				check(jump.landing-jump.takeoff>60.,"Gap is a real flight section")
				var mid:Dictionary=track.sample((jump.takeoff+jump.landing)*.5)
				check(not Track.supported(mid,0.) and not Track.supported(mid,mid.width*.5),"No invisible collision surface across the gap")
				check(Track.supported(track.sample(jump.takeoff-.01),0.) and Track.supported(track.sample(jump.landing+.01),0.),"Launch lip and landing share exact mesh boundaries")
				var p:Dictionary=race.racers[0]
				p.distance=jump.takeoff-160.;p.speed=250.;p.x=0.;p.heading=0.;p.slip=0.
				p.airborne=false;p.recovery=0.;p.crashed=false;p.wreck_wait=false;p.reset_held=false;p.trim=0.;p.lift=0.;p.unload=0.;p.lift_speed=0.;p.air_rates=Vector3.ZERO
				race.countdown=0.;race.clock=0.;race.over=false
				var launched:=false
				var landed:=false
				var launch_distance:=0.
				var peak:=0.
				for tick in range(120*12):
					var was_flying:bool=p.airborne
					race.step(1./120.,[race.bot(p)])
					if p.airborne:
						if not launched:
							launch_distance=p.distance
							check(p.air_velocity.distance_to(p.ground_velocity)<.001,"Ramp release preserves measured velocity without an impulse")
							check(p.air_position.distance_to(Flight.ground_pose(p,track.sample(p.distance),race.clock).origin)<.001,"Takeoff has no position snap")
						launched=true
						check(p.distance==launch_distance,"Flight cannot award progress before landing")
						peak=maxf(peak,p.lift)
					if was_flying and not p.airborne:
						landed=not p.crashed and p.distance>=jump.landing
						if not landed:
							var hit:Dictionary=track.project(p.air_position,p.distance,p.air_travel*1.35+100.)
							print("IMPACT ",hit.distance," height=",(p.air_position-hit.node.p).dot(hit.node.frame.y)," lateral=",hit.lateral," up=",p.air_frame.y.dot(hit.node.frame.y)," nose=",p.air_frame.z.dot(hit.node.frame.z)," descent=",p.air_velocity.dot(hit.node.frame.y))
						break
				check(launched and landed,"Bot lands %s seed %d %s (position %.1f / landing %.1f, peak %.1f)"%[difficulty,seed_value,jump.kind,p.distance,jump.landing,peak])
				print("JUMP ",difficulty," ",seed_value," ",jump.kind," ","PASS" if landed else "FAIL"," time=",race.clock," gap=",jump.landing-jump.takeoff)
				p.distance=jump.takeoff+5.;p.recovery=.01;p.crashed=true;p.wreck_wait=false
				p.finished=false;race.over=false
				race.step(.02,[{}])
				check(p.distance<=jump.takeoff-140. and Track.supported(track.sample(p.distance),p.x),"Failed jump respawns on a solid run-up")
	# Purpose-built catch decks tolerate an imperfect approach but still punish
	# hard touchdowns and reject steep or inverted impacts.
	var landing_race:=Race.new([{"slot":0}],31,1,"hard")
	var deck:float=landing_race.track.jumps[0].landing+25.
	var n:Dictionary=landing_race.track.sample(deck)
	for descent in [65.,180.]:
		var p:Dictionary=landing_race.racers[0]
		p.distance=deck;p.airborne=true;p.air_time=.5;p.air_travel=0.;p.crashed=false;p.recovery=0.;p.energy=100.
		p.air_position=Track.point(n,0.,1.5);p.air_frame=n.frame;p.air_velocity=n.frame.z*230.-n.frame.y*descent;p.air_rates=Vector3.ZERO;p.trim=0.
		Flight.step(p,landing_race.track,.01,0.,0.,.5,0.)
		check(p.crashed if descent>140. else not p.airborne and p.energy<100.,"Landing penalty and maximum descent remain meaningful")
	print("JUMP_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
