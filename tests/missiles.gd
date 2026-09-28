extends SceneTree
const Race=preload("res://src/race.gd")
const Audio=preload("res://src/missile_audio.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	for seed_value in [6,31,145,421]:
		var race:=Race.new([{"slot":2},{"slot":7}],seed_value,3,"hard")
		race.countdown=0.;race.clock=5.
		var owner:Dictionary=race.racers[1];var leader:Dictionary=race.racers[0]
		leader.distance=race.track.length*2.;owner.weapon="missile"
		race.weapons.activate(race,1)
		var m:Dictionary=race.weapons.missiles[0]
		var features:Dictionary={}
		while m.distance<race.track.length:
			var before:float=m.distance
			race.weapons.step_missile(race,m,1./60.)
			check(absf((m.distance-before)*60.-m.launch_speed)<.001,"Missile advances at its accelerating motor speed")
			var n:Dictionary=race.track.sample(m.distance)
			features[n.feature]=true
			if m.age>=race.Weapons.MISSILE_LAUNCH_TIME:
				check(absf(m.launch_speed-1500./3.6)<.001,"Cruise reaches 1500 km/h independent of lead gap")
				check(m.position.distance_to(Race.Track.point(n,m.x,10.))<.001,"Cruise follows banked road, loops and gaps without corner cutting")
		check(m.terminal<0. and race.weapons.missiles.size()==1,"Far-away leader does not force an early terminal dive or timeout")
		check(m.trail.size()<=race.Weapons.MISSILE_TRAIL_POINTS and features.size()>1,"Trail stays bounded through varied track features")
	# Terminal travel also respects the speed cap and produces exactly one hit.
	var race:=Race.new([{"slot":2},{"slot":7}],31)
	race.countdown=0.;race.clock=5.
	var leader:Dictionary=race.racers[0];var owner:Dictionary=race.racers[1]
	leader.distance=700.;owner.distance=500.;owner.weapon="missile";race.weapons.activate(race,1)
	var m:Dictionary=race.weapons.missiles[0];m.terminal=.2;m.age=2.
	m.position=race.Weapons.pose(race,leader).origin-race.track.sample(leader.distance).frame.z*30.
	var before:Vector3=m.position
	race.weapons.step_missile(race,m,.01)
	check(absf(m.position.distance_to(before)-race.Weapons.MISSILE_SPEED*.01)<.001,"Final approach flies at the same speed rather than teleporting to hit")
	for i in range(12):
		for missile in race.weapons.missiles.duplicate(): race.weapons.step_missile(race,missile,.01)
	check(leader.energy==62. and race.weapons.bursts.size()==1,"Impact damages once and creates one explosion")
	check(race.weapons.bursts[0].life==2.4,"Smoke persists after the initial flash")
	var wav:=Audio.synthesize()
	var peak:=0
	for i in range(wav.data.size()/2): peak=maxi(peak,absi(wav.data.decode_s16(i*2)))
	check(wav.get_length()>1.7 and peak>1000 and peak<32767,"Cached blast has a rumble tail and no clipped PCM samples")
	var audio:=Audio.new();root.add_child(audio)
	var camera:=Camera3D.new();root.add_child(camera);camera.position=race.weapons.bursts[0].position
	audio.update(race,[{"camera":camera}],true,false)
	check(audio.heard.size()==1 and audio.stream==null,"Muted playtest consumes audio event without playing or synthesizing")
	audio.update(race,[{"camera":camera}],true,true)
	check(audio.voices.all(func(v):return not v.playing),"Unmuting warms audio without replaying old explosions")
	race.weapons.bursts[0].id+=1;audio.update(race,[{"camera":camera}],true,true)
	check(audio.stream!=null and audio.voices.any(func(v):return v.playing),"A new audible impact plays a cached blast")
	audio.update(race,[{"camera":camera}],false,true)
	check(audio.voices.filter(func(v):return v.stream!=null).all(func(v):return v.stream_paused),"Pause freezes explosion audio")
	audio.update(race,[{"camera":camera}],true,false)
	await create_timer(.1).timeout
	audio.free();camera.free()
	await create_timer(.1).timeout
	print("MISSILE_TESTS %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
