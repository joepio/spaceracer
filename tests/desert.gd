extends SceneTree
const Race=preload("res://src/race.gd")
const Desert=preload("res://src/desert.gd")
const Sandworm=preload("res://src/sandworm.gd")
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
	var worm_sites:=0
	var arch_count:=0
	for seed_value in [31,32,421]:
		for difficulty in ["easy","hard"]:
			var started:=Time.get_ticks_msec()
			var race:=Race.new([{"slot":0},{"slot":1,"bot":true}],seed_value,1,difficulty,"desert")
			race.track.obstacles=Track.HazardCollision.new()
			var stage:=Node3D.new();root.add_child(stage)
			var desert:=Desert.new();desert.build(stage,race)
			var elapsed:=Time.get_ticks_msec()-started
			var replica_stage:=Node3D.new();root.add_child(replica_stage)
			var replica:=Desert.new();replica.build(replica_stage,race)
			check(desert.terrain.heights==replica.terrain.heights and desert.rocks==replica.rocks and desert.cacti==replica.cacti,"Desert reproduces from the seed")
			check(desert.terrain.maximum-desert.terrain.minimum>250.,"Dunes rise into tall sandstone ranges")
			check(desert.rocks.size()>120 and desert.cacti.size()>60,"Hoodoos, boulders and cacti populate the dunes")
			check(desert.layout.billboards.is_empty() and desert.traffic.instance_count==0 and desert.local_lights.is_empty(),"City ads, traffic and lights stay out of the desert")
			check(desert.probes.size()==3,"Lighting has a bounded shared capture budget")
			check(not race.track.nodes.any(func(n):return n.tunnel),"Desert tunnels become open slot canyons")
			arch_count+=desert.arches.size()
			worm_sites+=desert.worm.sites.size()
			check(desert.worm.sites.size()>=2,"The sandworm has places to erupt: %d %s"%[seed_value,difficulty])
			# The road, its full width and a flight envelope stay clear of rock.
			var props:Array[AABB]=[]
			for rock in desert.rocks: props.append(rock.bounds)
			for cactus in desert.cacti: props.append(cactus.bounds)
			var walls:=0
			for index in range(0,race.track.nodes.size(),6):
				var n:Dictionary=race.track.nodes[index]
				for lateral in [-.95,0.,.95]:
					var p:=Track.point(n,n.width*lateral,2.)
					check(desert.terrain.height_at(p.x,p.z)<p.y-8.,"Sand and rock stay below the full road cross-section")
					var blocked:=false
					for bounds in props:
						if bounds.has_point(p): blocked=true;break
					check(not blocked,"Rocks and cacti keep the complete route clear")
					check(race.track.obstacles.trace(p,p+n.frame.z*2.,1.).is_empty(),"No collision volume crosses the racing line")
				var side:Vector3=-n.frame.x;side.y=0.;side=side.normalized()
				for reach in [140.,-140.]:
					var q:Vector3=n.p+side*reach
					if desert.terrain.height_at(q.x,q.z)>n.p.y+40.: walls+=1
			check(walls>race.track.nodes.size()/6*.25,"The course threads through canyon walls: %d"%walls)
			for arch in desert.arches:
				check(arch.crown>=72.,"Arches leave tall clearance over the course")
			# Erupt ahead of a pilot and inspect the arc over the road.
			var worm:RefCounted=desert.worm
			if worm.sites.is_empty(): continue
			var site:Dictionary=worm.sites[0]
			race.racers[0].distance=site.distance-350.
			worm.animate(1.)
			check(worm.active==0 and worm.eruptions==1,"An approaching pilot wakes the sandworm")
			var peak_time:float=1.+(float(site.total)*.5-float(site.lead))/Sandworm.SPEED
			worm.animate(peak_time)
			check(worm.head.visible and worm.body_node.visible,"Worm is above ground mid-arc")
			var n:Dictionary=race.track.sample(site.distance)
			check(worm.head.global_position.y>n.p.y+60.,"Head clears the road by a wide margin at its apex")
			worm.animate(1.+(float(site.surface_b)-float(site.lead))/Sandworm.SPEED+1.)
			var visible_dust:=0
			for i in range(Sandworm.DUST):
				if worm.dust.get_instance_color(i).a>.01: visible_dust+=1
			check(visible_dust>20,"Sand sprays from the holes as the body passes")
			worm.animate(peak_time+60.)
			worm.animate(.5)
			check(worm.active<0 or worm.sites[worm.active].start<=.5,"Clock restarts reset the eruption schedule")
			desert.animate(3.5)
			check(desert.animation_time==3.5,"Desert uses the pausable race clock")
			print("DESERT seed=",seed_value," ",difficulty," build_ms=",elapsed," rocks=",desert.rocks.size()," cacti=",desert.cacti.size()," arches=",desert.arches.size()," worm_sites=",desert.worm.sites.size()," walls=",walls," relief=",desert.terrain.maximum-desert.terrain.minimum)
			stage.free();replica_stage.free()
			await process_frame
	check(arch_count>=4,"Natural arches span the course across seeds")
	print("DESERT_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
