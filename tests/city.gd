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
		check(city.buildings==repeat.buildings and city.signs==repeat.signs and city.routes==repeat.routes and city.billboards==repeat.billboards,"City generation is deterministic")
		check(city.buildings.size()>700,"Dense city has enough buildings")
		check(city.signs.size()>=6 and city.routes.size()>=12,"City has readable signs and safe traffic routes")
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
			broad=broad or building.width>145
			var collision:=false
			for ribbon in road:
				if ribbon.intersects(building.bounds): collision=true;break
			check(not collision,"Building envelope clears full road including loops/banking")
		check(kinds.size()==8,"All eight architecture types appear")
		check(roofs.size()==6 and narrow and broad,"Skyline includes varied roof silhouettes and genuinely different widths")
		for item in city.signs+city.routes:
			var collision:=false
			for ribbon in road:
				if ribbon.intersects(item.bounds): collision=true;break
			check(not collision and not city.occupied(item.bounds),"Signs and traffic routes clear road and buildings")
		check(not city.clear(AABB(track.nodes[0].p-Vector3.ONE,Vector3.ONE*2)),"Road itself cannot become a city lot")
		print("CITY seed=",seed_value," buildings=",city.buildings.size()," signs=",city.signs.size()," airlanes=",city.routes.size()," billboards=",city.billboards.size())
	# Audit actual generated mesh bounds as well as reserved building envelopes.
	var race=load("res://src/race.gd").new([{"slot":0}],31)
	var scenery=load("res://src/scenery.gd").new()
	var world:=Node3D.new()
	root.add_child(world)
	scenery.build(world,race)
	for child in world.get_children():
		if not child is MultiMeshInstance3D: continue
		var data:MultiMesh=child.multimesh
		if data in [scenery.traffic,scenery.cabins,scenery.lamps]: continue
		for i in range(data.instance_count):
			var bounds: AABB=data.get_instance_transform(i)*data.mesh.get_aabb()
			check(scenery.layout.clear(bounds),"Rendered architecture stays out of the road corridor")
	world.free()
	print("CITY_TESTS %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
