extends SceneTree
const Race=preload("res://src/race.gd")
const Forest=preload("res://src/forest.gd")
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
	for variant in range(Forest.Assets.PATHS.size()):
		var model:=Forest.Assets.model(variant)
		check(not model.solids.is_empty(),"Authored trees retain solid trunk collision")
		for part in model.parts:
			var bounds:AABB=part.transform*part.mesh.get_aabb()
			check(bounds.position.y>=-.001 and bounds.end.y<=1.001,"Imported scene hierarchy normalizes to one metre tall")
			check(part.mesh==Forest.Assets.model(variant).parts[model.parts.find(part)].mesh,"Instances share cached imported meshes")
	for seed_value in [31,421]:
		var race:=Race.new([{"slot":0}],seed_value,1,"hard","forest")
		var stage:=Node3D.new();root.add_child(stage)
		var forest:=Forest.new();forest.build(stage,race)
		check(forest.trees.size()>350 and forest.plants.size()>1500,"Forest is densely populated with giant trees and ferns")
		var replica_stage:=Node3D.new();root.add_child(replica_stage)
		var replica:=Forest.new();replica.build(replica_stage,race)
		check(forest.trees==replica.trees and forest.plants==replica.plants,"Forest scenery reproduces from the seed")
		check(forest.local_lights.is_empty() and forest.probes.size()==3,"Lighting has a bounded shared capture budget")
		check(forest.layout.billboards.is_empty() and forest.traffic.instance_count==0,"City ads and air traffic do not leak into the forest")
		var giants:int=forest.trees.filter(func(tree):return tree.height>=340.).size()
		check(giants>forest.trees.size()*.6,"Towering trees dominate the dense canopy")
		var variants:Dictionary={}
		var smallest:=INF;var tallest:=0.
		for tree in forest.trees:
			variants[tree.variant]=true
			smallest=minf(smallest,tree.height);tallest=maxf(tallest,tree.height)
		check(variants.size()==Forest.Assets.PATHS.size() and tallest/smallest>5.,"Both authored species and a broad height spread")
		check(forest.shore_image.get_width()==512,"Shoreline baking uses a bounded texture budget")
		check(forest.terrain.maximum-forest.terrain.minimum>60.,"Landscape has rolling hills and submerged valleys")
		check(forest.terrain.heights==replica.terrain.heights,"Landscape height map is seed deterministic")
		var vegetation:Array[AABB]=[]
		for tree in forest.trees:
			check(tree.height>=80 and tree.height<=650,"Trees retain the bounded young-to-giant size range")
			vegetation.append_array(tree.bounds)
		vegetation.append_array(forest.plants)
		# Independently audit sampled racing points, including pipe walls and flight
		# corridors, against the actual recorded vegetation envelopes.
		for index in range(0,race.track.nodes.size(),12):
			var n:Dictionary=race.track.nodes[index]
			check(n.p.y>forest.water_level+20.,"Water never intersects the driving surface")
			for lateral in [-.95,0.,.95]:
				var p:=Track.point(n,n.width*lateral,2.)
				check(forest.terrain.height_at(p.x,p.z)<p.y-8.,"Landscape stays below the full road cross-section")
				var blocked:=false
				for bounds in vegetation:
					if bounds.has_point(p): blocked=true;break
				check(not blocked,"Trees, crowns and ferns keep the complete route clear")
		forest.animate(3.5)
		check(forest.water.get_shader_parameter("race_time")==3.5 and forest.understory.get_shader_parameter("race_time")==3.5,"Water and undergrowth use the pausable race clock")
		var pilot:Dictionary=race.racers[0]
		pilot.airborne=true;pilot.air_time=.5;pilot.distance=100.
		pilot.air_position=race.track.sample(100.).p;pilot.air_position.y=forest.water_level-1.
		pilot.air_velocity=Vector3(0.,-20.,200.);pilot.air_frame=Basis.IDENTITY
		Race.Flight.step(pilot,race.track,.01,0.,0.,0.,0.)
		check(pilot.crashed and pilot.wreck_wait and pilot.recovery==0,"Water impact waits for reset instead of allowing underwater flight")
		print("FOREST seed=",seed_value," trees=",forest.trees.size()," ferns=",forest.plants.size()," water=",forest.water_level)
		stage.free();replica_stage.free()
	var completed:=0
	for difficulty in Track.DIFFICULTIES:
		for seed_value in [6,31,145,421]:
			var roster:Array=[]
			for slot in range(6): roster.append({"slot":slot,"bot":true})
			var race:=Race.new(roster,seed_value,1,difficulty,"forest")
			for tick in range(120*120):
				var inputs:Array=[]
				for p in race.racers: inputs.append(race.bot(p))
				race.step(1./120.,inputs)
				if race.over: break
			var count:int=race.racers.filter(func(p):return p.finished).size()
			completed+=count
			check(count==6,"All racers finish forest seed %d at %s"%[seed_value,difficulty])
			print("FOREST_RACE ",difficulty," ",seed_value," ",count,"/6 time=",race.clock)
	print("FOREST_TESTS ",checks," checks, ",failures," failures; ",completed,"/72 finishers")
	quit(1 if failures else 0)
