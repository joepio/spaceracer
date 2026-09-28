extends RefCounted
## Clockwise street circuits occupy the inner lane around each city block.
## Adjacent blocks form opposing traffic; rounded junction quadrants do not cross.
## Four shared meshes and GPU animation, no per-car nodes or per-frame uploads.
const Traffic=preload("res://src/city_traffic.gd")
const Layout=preload("res://src/city_layout.gd")
const SCALE:=.72
const HEIGHT:=Layout.FLOOR-.5+.75*SCALE
const SEGMENT:=88.+12.*PI*.5
const LENGTH:=SEGMENT*4.
var material:ShaderMaterial
var renderers:Array[MultiMeshInstance3D]=[]
var routes:Array[Dictionary]=[]
var cars:Array[Dictionary]=[]
var buckets:Dictionary={}
var clock:=0.

static func local_frame(distance:float)->Transform3D:
	var progress:=fposmod(distance,LENGTH)
	var side:=floori(progress/SEGMENT)
	var along:=fposmod(progress,SEGMENT)
	var point:Vector3;var forward:Vector3
	if along<88.:
		point=Vector3(-44.+along,0.,-56.);forward=Vector3.RIGHT
	else:
		var angle:=(along-88.)/12.-PI*.5
		point=Vector3(44.+cos(angle)*12.,0.,-44.+sin(angle)*12.)
		forward=Vector3(-sin(angle),0.,cos(angle))
	var turn:=Basis(Vector3.UP,-side*PI*.5)
	point=turn*point;forward=turn*forward
	return Transform3D(Basis(Vector3.UP.cross(forward),Vector3.UP,forward),point)

func build(parent:Node3D,layout:RefCounted,seed_value:int)->void:
	material=ShaderMaterial.new();material.shader=load("res://src/ground_traffic.gdshader")
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value+84031
	var groups:Dictionary={}
	# Local building buckets make the one-time street clearance audit cheap.
	var lots:Dictionary={}
	for building in layout.buildings:
		for cell in Layout.cells(building.bounds):
			if not lots.has(cell): lots[cell]=[]
			lots[cell].append(building.bounds)
	for podium in layout.podiums:
		for cell in Layout.cells(podium.bounds):
			if not lots.has(cell): lots[cell]=[]
			lots[cell].append(podium.bounds)
	for x in range(-17,18):
		for z in range(-17,18):
			var center:=Vector3(x*120.,HEIGHT,z*120.)
			if not clear_loop(center,layout,lots): continue
			var bounds:=AABB(center+Vector3(-59.,-.6,-59.),Vector3(118.,3.5,118.))
			var route:={"center":center,"bounds":bounds,"cars":[]}
			var route_id:=routes.size();routes.append(route)
			for cell in Layout.cells(bounds):
				if not buckets.has(cell): buckets[cell]=[]
				buckets[cell].append(route_id)
			var congested:=rng.randf()<.28
			var count:=rng.randi_range(17,21) if congested else rng.randi_range(10,15)
			var speed:=rng.randf_range(1.5,4.) if congested else rng.randf_range(10.,17.)
			var phase:=rng.randf()*LENGTH;var pulse:=rng.randf()*TAU
			for i in range(count):
				var variant:=rng.randi_range(0,3)
				var car:={"center":center,"phase":fposmod(phase+float(i)*LENGTH/count,LENGTH),"speed":speed,"pulse":pulse,"variant":variant,"color":Traffic.PALETTE[rng.randi_range(0,5)]}
				route.cars.append(cars.size());cars.append(car)
				var key:=Vector3i(variant,floori(center.x/720.),floori(center.z/720.))
				if not groups.has(key): groups[key]={"cars":[],"bounds":bounds}
				groups[key].cars.append(car);groups[key].bounds=groups[key].bounds.merge(bounds)
	var meshes:Array[ArrayMesh]=[]
	for variant in range(4): meshes.append(Traffic.vehicle_mesh(variant,true))
	for key in groups:
		var group:Dictionary=groups[key]
		var data:=MultiMesh.new();data.transform_format=MultiMesh.TRANSFORM_3D
		data.use_colors=true;data.use_custom_data=true;data.mesh=meshes[key.x];data.instance_count=group.cars.size()
		data.custom_aabb=group.bounds
		for i in range(data.instance_count):
			var car:Dictionary=group.cars[i]
			data.set_instance_transform(i,Transform3D(Basis.IDENTITY,car.center))
			data.set_instance_color(i,car.color)
			data.set_instance_custom_data(i,Color(car.phase,car.speed,0.,car.pulse))
		var renderer:=MultiMeshInstance3D.new();renderer.name="GroundTraffic%d_%d_%d"%[key.x,key.y,key.z]
		renderer.multimesh=data;renderer.material_override=material;renderer.layers=2
		renderer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		renderer.set_meta("gi_dynamic",true);renderer.set_meta("ground_traffic",true)
		parent.add_child(renderer);renderers.append(renderer)

static func clear_loop(center:Vector3,layout:RefCounted,lots:Dictionary)->bool:
	# Audit straight endpoints and 8 subdivisions of each 90-degree corner.
	# Each envelope also covers the rotated vehicle, not just its centerline.
	var samples:Array[Transform3D]=[]
	for side in range(4):
		samples.append(local_frame(side*SEGMENT))
		for j in range(9): samples.append(local_frame(side*SEGMENT+88.+j*12.*PI*.5/8.))
	var car:=AABB(Vector3(-2.,-.55,-5.15),Vector3(4.,3.5,10.3))
	for i in range(samples.size()):
		var a:Transform3D=samples[i];var b:Transform3D=samples[(i+1)%samples.size()]
		a.origin+=center;b.origin+=center
		var region: AABB=(a*car).merge(b*car).grow(.12)
		if not layout.clear(region): return false
		for cell in Layout.cells(region):
			for lot:AABB in lots.get(cell,[]):
				if not lot.intersects(region): continue
				if a.basis.z.dot(b.basis.z)>.999: return false
				# An AABB around a turning car includes empty inside-corner space.
				# Test its oriented footprint, with enough padding to cover motion
				# between the start/middle/end samples of this short arc.
				for t in [0.,.5,1.]:
					if overlaps_lot(a.interpolate_with(b,t),lot): return false
	return true

static func overlaps_lot(frame:Transform3D,lot:AABB)->bool:
	var delta:Vector3=lot.get_center()-frame.origin
	var half:Vector3=lot.size*.5
	for axis in [Vector3.RIGHT,Vector3.BACK,frame.basis.x,frame.basis.z]:
		var vehicle:float=2.9*absf(axis.dot(frame.basis.x))+6.05*absf(axis.dot(frame.basis.z))
		var building:float=half.x*absf(axis.x)+half.z*absf(axis.z)
		if absf(delta.dot(axis))>vehicle+building: return false
	return true

func animate(time:float)->void:
	clock=time;material.set_shader_parameter("traffic_time",time)

func car_frame(car:Dictionary)->Transform3D:
	var flow:float=clock*car.speed+car.speed*.85/.24*(sin(clock*.24+car.pulse)-sin(car.pulse))
	var frame:=local_frame(car.phase+flow)
	frame.origin+=car.center;frame.basis=frame.basis.scaled(Vector3.ONE*SCALE)
	return frame

func trace(from:Vector3,to:Vector3,radius:float)->Dictionary:
	var query:=AABB(from,Vector3.ZERO).expand(to).grow(radius)
	if query.end.y<HEIGHT-.6 or query.position.y>HEIGHT+3.: return {}
	var seen:Dictionary={};var nearest:Dictionary={};var best:=INF
	for cell in Layout.cells(query):
		for id in buckets.get(cell,[]):
			if seen.has(id): continue
			seen[id]=true
			var route:Dictionary=routes[id]
			if not route.bounds.intersects(query): continue
			for index in route.cars:
				var car:Dictionary=cars[index];var frame:=car_frame(car)
				var size:Vector3=Traffic.SIZES[car.variant]
				var box:=AABB(Vector3(-size.x*.5,-.75,-size.z*.5),size+Vector3(0,.15,0)).grow(radius/SCALE)
				if not (frame*box).intersects(query): continue
				var contact:Dictionary=load("res://src/obstacles.gd").box_contact(frame.affine_inverse(),box,from,to)
				if not contact.is_empty():
					var distance:=from.distance_squared_to(contact.position)
					if distance<best: best=distance;nearest=contact
	return nearest
