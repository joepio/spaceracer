extends SceneTree
const Race=preload("res://src/race.gd")
const Ocean=preload("res://src/ocean.gd")
const OceanLife=preload("res://src/ocean_life.gd")
const Track=preload("res://src/track.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<12: push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	var octopus_count:=0
	for seed_value in [31,32,421]:
		for difficulty in ["easy","hard"]:
			var started:=Time.get_ticks_msec()
			var race:=Race.new([{"slot":0},{"slot":1,"bot":true}],seed_value,1,difficulty,"ocean")
			race.track.obstacles=Track.HazardCollision.new()
			var stage:=Node3D.new();root.add_child(stage)
			var ocean:=Ocean.new();ocean.build(stage,race)
			var elapsed:=Time.get_ticks_msec()-started
			var replica_stage:=Node3D.new();root.add_child(replica_stage)
			var replica:=Ocean.new();replica.build(replica_stage,race)
			check(ocean.terrain.heights==replica.terrain.heights and ocean.rocks==replica.rocks and ocean.plants==replica.plants,"The reef reproduces from the seed")
			check(ocean.terrain.maximum-ocean.terrain.minimum>200.,"The seafloor rises into tall reefs and seamounts")
			var kinds:={}
			for plant in ocean.plants: kinds[plant.kind]=kinds.get(plant.kind,0)+1
			check(kinds.get(Ocean.KELP,0)>150 and kinds.get(Ocean.LANTERN,0)>20 and kinds.get(Ocean.FAN,0)>20 and kinds.get(Ocean.SPONGE,0)>20,"Kelp, lantern weed, sea fans and sponges all grow: %s"%kinds)
			check(ocean.rocks.size()>80,"Reef boulders are scattered over the seafloor")
			check(ocean.layout.billboards.is_empty() and ocean.traffic.instance_count==0 and ocean.local_lights.is_empty(),"City ads, traffic and lights stay out of the ocean")
			check(not race.track.nodes.any(func(n):return n.tunnel),"Tunnels become open reef trenches")
			var life:RefCounted=ocean.life
			check(life.fish.instance_count==OceanLife.SCHOOLS*OceanLife.FISH_PER_SCHOOL,"Fish schools are populated")
			check(life.jellies.size()>40,"Jellyfish swarms drift near the course: %d"%life.jellies.size())
			check(life.mantas.size()==OceanLife.MANTAS,"Manta rays glide overhead")
			check(life.octopuses.size()>=2,"Giant octopuses lurk beside the course: %d %s"%[seed_value,difficulty])
			octopus_count+=life.octopuses.size()
			# Octopus arms stay well away from the racing line.
			for octopus in life.octopuses:
				for index in range(0,race.track.nodes.size(),3):
					var n:Dictionary=race.track.nodes[index]
					var flat:=Vector2(octopus.position.x-n.p.x,octopus.position.z-n.p.z).length()
					check(flat>octopus.arm+n.width+20.,"Octopus arms cannot reach the road")
			for jelly in life.jellies:
				check(ocean.course_clear(jelly.home,jelly.size*2.,jelly.size),"Jellyfish keep out of the road envelope")
			var props:Array[AABB]=[]
			for rock in ocean.rocks: props.append(rock.bounds)
			for plant in ocean.plants: props.append(plant.bounds)
			var walls:=0
			for index in range(0,race.track.nodes.size(),6):
				var n:Dictionary=race.track.nodes[index]
				for lateral in [-.95,0.,.95]:
					var p:=Track.point(n,n.width*lateral,2.)
					check(ocean.terrain.height_at(p.x,p.z)<p.y-8.,"The seafloor stays below the full road cross-section")
					var blocked:=false
					for bounds in props:
						if bounds.has_point(p): blocked=true;break
					check(not blocked,"Rocks and plants keep the complete route clear")
					check(race.track.obstacles.trace(p,p+n.frame.z*2.,1.).is_empty(),"No collision volume crosses the racing line")
				var side:Vector3=-n.frame.x;side.y=0.;side=side.normalized()
				for reach in [140.,-140.]:
					var q:Vector3=n.p+side*reach
					if ocean.terrain.height_at(q.x,q.z)>n.p.y+40.: walls+=1
			check(walls>race.track.nodes.size()/6*.2,"The course threads through reef walls: %d"%walls)
			# Creatures move with the pausable race clock and return to the same pose.
			var before:Vector3=life.fish_positions[0]
			ocean.animate(4.)
			check(life.fish_positions[0].distance_to(before)>5.,"Fish swim as the clock runs")
			check(ocean.animation_time==4.,"The ocean uses the pausable race clock")
			ocean.animate(0.)
			check(life.fish_positions[0].is_equal_approx(before),"The same clock gives the same pose")
			print("OCEAN seed=",seed_value," ",difficulty," build_ms=",elapsed," rocks=",ocean.rocks.size()," plants=",kinds," jellies=",life.jellies.size()," octopuses=",life.octopuses.size()," arches=",ocean.arches.size()," walls=",walls)
			stage.free();replica_stage.free()
			await process_frame
	check(octopus_count>=12,"Octopuses appear on every seed")
	print("OCEAN_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
