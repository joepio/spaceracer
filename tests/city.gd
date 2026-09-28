extends SceneTree
const Track=preload("res://src/track.gd")
const Layout=preload("res://src/city_layout.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<12: push_error(message)
func _initialize()->void:
	call_deferred("run")
func run()->void:
	for seed_value in [1,2,3,9,17,31,42,145]:
		var track:=Track.new(seed_value)
		var city:=Layout.new(track)
		var repeat:=Layout.new(track)
		check(city.buildings==repeat.buildings and city.routes==repeat.routes and city.billboards==repeat.billboards,"City generation is deterministic")
		check(city.buildings.size()>2000,"Manhattan blocks contain substantially more buildings")
		check(city.routes.size()>=12,"City has safe traffic routes")
		check(city.billboards.size()>=8,"City has prominent building-mounted advertisements")
		for board in city.billboards:
			check(city.buildings[board.building].bounds.encloses(board.bounds) and city.clear(board.bounds),"Mounted billboard stays within its safe building envelope")
		var kinds:Dictionary={}
		var roofs:Dictionary={}
		var narrow:=false
		var broad:=false
		# Independent brute-force audit of the entire swept ribbon (not the spatial hash).
		var road:Array[AABB]=[]
		for i in range(track.nodes.size()):
			var a:Dictionary=track.nodes[i]
			var b:Dictionary=track.nodes[(i+1)%track.nodes.size()]
			road.append(AABB(a.p,Vector3.ZERO).expand(b.p).grow(maxf(a.width,b.width)+18))
		for building in city.buildings:
			kinds[building.kind]=true
			roofs[building.roof]=true
			narrow=narrow or building.width<35
			broad=broad or building.width>90
			var block:Vector2i=building.block
			check(absf(building.center.x-block.x*120.)+building.width*.5<=48. and absf(building.center.z-block.y*120.)+building.depth*.5<=48.,"Buildings align within blocks and leave a continuous street grid")
			var collision:=false
			for ribbon in road:
				if ribbon.intersects(building.bounds): collision=true;break
			check(not collision,"Building envelope clears full road including loops/banking")
		check(kinds.size()==8,"All eight architecture types appear")
		check(roofs.size()==6 and narrow and broad,"Skyline includes varied roof silhouettes and genuinely different widths")
		for item in city.routes:
			var collision:=false
			for ribbon in road:
				if ribbon.intersects(item.bounds): collision=true;break
			check(not collision and not city.occupied(item.bounds),"Traffic routes clear road and buildings")
		check(not city.clear(AABB(track.nodes[0].p-Vector3.ONE,Vector3.ONE*2)),"Road itself cannot become a city lot")
		print("CITY seed=",seed_value," buildings=",city.buildings.size()," airlanes=",city.routes.size()," billboards=",city.billboards.size())
	# Independently sample the driving surface against each new fixture envelope.
	# Dense lateral and longitudinal samples catch poles over either racing edge.
	for seed_value in [1,31,145]:
		var track:=Track.new(seed_value)
		var stage:=Node3D.new()
		root.add_child(stage)
		var district=load("res://src/showpiece.gd").new()
		district.build(stage,track)
		check(not district.fixtures.is_empty(),"Opening has visible streetlight fixtures")
		for fixture in district.fixtures:
			var clear_surface:=true
			for i in range(track.nodes.size()):
				var a:Dictionary=track.nodes[i]
				var b:Dictionary=track.nodes[(i+1)%track.nodes.size()]
				for step_index in range(9):
					var along:=float(step_index)/8.
					for across in [-1.,-.75,-.5,-.25,0.,.25,.5,.75,1.]:
						var point:Vector3=Track.point(a,a.width*across,0).lerp(Track.point(b,b.width*across,0),along)
						if fixture.bounds.grow(.5).has_point(point): clear_surface=false
			check(clear_surface,"Streetlight poles clear sampled racing surface, including crossings")
		stage.free()
	# Audit actual generated mesh bounds as well as reserved building envelopes.
	var race=load("res://src/race.gd").new([{"slot":0}],31)
	var scenery=load("res://src/scenery.gd").new()
	var world:=Node3D.new()
	root.add_child(world)
	scenery.build(world,race)
	check(scenery.neon.signs.size()>=320 and scenery.neon.signs.size()<=640,"City has hundreds of attached neon signs within a fixed budget")
	check(scenery.local_lights.size()<=64,"Artwork and neon share a bounded local light budget")
	for sign in scenery.neon.signs:
		check(scenery.layout.buildings.any(func(building):return building.bounds.encloses(sign.bounds)),"Neon housing stays inside an audited building lot")
		check(scenery.layout.clear(sign.bounds),"Neon housing clears the driving and flight corridors")
	for child in world.get_children():
		if not child is MultiMeshInstance3D: continue
		if child.get_meta("air_traffic",false): continue # Shader-motion bounds audited in city_traffic.gd.
		if child.get_meta("ground_traffic",false): continue # Ground circuits audit the whole swept car volume.
		var data:MultiMesh=child.multimesh
		if data in [scenery.traffic,scenery.cabins,scenery.lamps]: continue
		for i in range(data.instance_count):
			var bounds: AABB=data.get_instance_transform(i)*data.mesh.get_aabb()
			check(scenery.layout.clear(bounds),"Rendered architecture stays out of the road corridor")
	world.free()
	print("CITY_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
