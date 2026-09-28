extends RefCounted
## Four shared single-surface meshes, batched by air corridor for culling.
## GPU motion shares the same clock as analytical
## collisions; only lanes near a swept collision query are inspected on the CPU.
const Cells=preload("res://src/city_layout.gd")
const SIZES:=[Vector3(3.7,2.1,7.),Vector3(4.7,2.2,10.),Vector3(4.4,1.7,9.),Vector3(5.2,3.8,14.)]
const PALETTE:=[Color("8996a1"),Color("3d5268"),Color("753b40"),Color("ad9560"),Color("ced3cc"),Color("344641")]
var material:ShaderMaterial
var batches:Array[MultiMesh]=[]
var renderers:Array[MultiMeshInstance3D]=[]
var routes:Array[Dictionary]=[]
var buckets:Dictionary={}
var cars:Array[Dictionary]=[]
var clock:=0.

static func add_mesh(tool:SurfaceTool,mesh:Mesh,position:Vector3,scale_value:Vector3,kind:float)->void:
	var arrays:=mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		tool.set_normal((normals[index]/scale_value).normalized())
		tool.set_uv2(Vector2(kind,0.))
		tool.set_color(Color.WHITE)
		tool.add_vertex(vertices[index]*scale_value+position)

static func hull(tool:SurfaceTool,sections:Array,kind:float)->void:
	# Chamfered cross-sections avoid the old stacked-box silhouette.
	var ring:=[Vector2(-.72,-.5),Vector2(.72,-.5),Vector2(1.,-.15),Vector2(.68,.5),Vector2(-.68,.5),Vector2(-1.,-.15)]
	for j in range(sections.size()-1):
		for side in range(6):
			var points:Array[Vector3]=[]
			for pair in [[j,side],[j,(side+1)%6],[j+1,(side+1)%6],[j+1,side]]:
				var s:Vector4=sections[pair[0]];var p:Vector2=ring[pair[1]]
				points.append(Vector3(p.x*s.x,p.y*s.y+s.w,s.z))
			var normal:Vector3=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
			for index in [0,2,1,0,3,2]:
				tool.set_normal(normal);tool.set_uv2(Vector2(kind,0.));tool.set_color(Color.WHITE);tool.add_vertex(points[index])
	for end in [0,sections.size()-1]:
		var s:Vector4=sections[end]
		for side in range(6):
			var a:Vector2=ring[side];var b:Vector2=ring[(side+1)%6]
			var vertices:=[Vector3(0,s.w,s.z),Vector3(a.x*s.x,a.y*s.y+s.w,s.z),Vector3(b.x*s.x,b.y*s.y+s.w,s.z)]
			for index in ([0,1,2] if end==0 else [0,2,1]):
				tool.set_normal(Vector3.BACK if end>0 else Vector3.FORWARD);tool.set_uv2(Vector2(kind,0.));tool.set_color(Color.WHITE);tool.add_vertex(vertices[index])

static func vehicle_mesh(variant:int,ground:bool=false)->ArrayMesh:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size:Vector3=SIZES[variant];var w:=size.x*.5;var l:=size.z*.5
	hull(tool,[Vector4(w*.85,.85,-l,0),Vector4(w,1.1,-l*.55,0),Vector4(w,1.1,l*.45,0),Vector4(w*.7,.6,l,-.1)],0.)
	if variant==3:
		hull(tool,[Vector4(w*.88,2.5,-l*.83,1.15),Vector4(w*.88,2.5,l*.34,1.15)],0.)
		hull(tool,[Vector4(w*.73,1.6,l*.36,1.05),Vector4(w*.66,.65,l*.77,.65)],1.)
	else:
		var roof:=size.y-.55
		hull(tool,[Vector4(w*.75,.28,-l*.6,.58),Vector4(w*.65,roof,-l*.22,.65),Vector4(w*.61,roof,l*.2,.65),Vector4(w*.63,.18,l*.63,.55)],1.)
		if variant==2:
			add_mesh(tool,BoxMesh.new(),Vector3(0,.62,-l*.78),Vector3(size.x*1.12,.16,.6),0.)
	for side in [-1.,1.]:
		if ground:
			for end in [-1.,1.]:
				add_mesh(tool,BoxMesh.new(),Vector3(side*w*.86,-.36,end*l*.57),Vector3(.36,.75,1.15),4.)
		# Flush emissive lenses need only their exposed face, no hidden box sides.
		for end in [-1.,1.]:
			var center:=Vector3(side*w*(.49 if end>0. else .56),.04,end*(l+.04))
			var width:=w*(.35 if end>0. else .4)
			var corners:=[Vector3(-width*.5,-.13,0),Vector3(width*.5,-.13,0),Vector3(width*.5,.13,0),Vector3(-width*.5,.13,0)]
			for index in ([0,2,1,0,3,2] if end>0. else [0,1,2,0,2,3]):
				tool.set_normal(Vector3(0,0,end));tool.set_color(Color.WHITE);tool.set_uv2(Vector2(2. if end>0. else 3.,0.));tool.add_vertex(center+corners[index])
			if ground:
				# Small upper lenses keep the head/tail distinction visible from the
				# elevated race track without billboard sprites or extra light nodes.
				var top:=Vector3(center.x,.27 if end>0. else .46,end*(l-.35))
				var lens:=[Vector3(-width*.5,0,-.18),Vector3(width*.5,0,-.18),Vector3(width*.5,0,.18),Vector3(-width*.5,0,.18)]
				for index in [0,1,2,0,2,3]:
					tool.set_normal(Vector3.UP);tool.set_color(Color.WHITE);tool.set_uv2(Vector2(2. if end>0. else 3.,0.));tool.add_vertex(top+lens[index])
	tool.index()
	return tool.commit()

func build(parent:Node3D,layout:RefCounted,seed_value:int)->void:
	material=ShaderMaterial.new();material.shader=load("res://src/city_traffic.gdshader")
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value+9407
	var groups:Dictionary={}
	for source in layout.routes:
		var route:Dictionary=source.duplicate();route.cars=[]
		var route_id:=routes.size();routes.append(route)
		for cell in Cells.cells(route.bounds):
			if not buckets.has(cell): buckets[cell]=[]
			buckets[cell].append(route_id)
		var count:=maxi(3,floori(route.length/rng.randf_range(60.,85.)))
		var spacing:float=route.length/count
		# A lane has one cruise speed: cars retain safe headways instead of passing
		# through one another. Adjacent lanes and heights have different speeds.
		var speed:=rng.randf_range(42.,78.);var phase:=rng.randf()*spacing
		route.spacing=spacing;route.phase=phase;route.speed=speed
		var basis:=Basis(Vector3.UP,PI*.5*route.direction)
		var origin:Vector3=route.start+Vector3.RIGHT*(route.length if route.direction<0 else 0.)
		for i in range(count):
			var variant:=rng.randi_range(0,3)
			var car:={"variant":variant,"phase":fposmod(i*spacing+phase+rng.randf_range(-spacing*.12,spacing*.12),route.length),"speed":speed,
				"length":route.length,"basis":basis,"origin":origin,"color":PALETTE[rng.randi_range(0,PALETTE.size()-1)]}
			route.cars.append(cars.size());cars.append(car)
			var key:=Vector3i(variant,floori(route.start.z/640.),roundi(route.start.y))
			if not groups.has(key): groups[key]={"cars":[],"bounds":route.bounds}
			groups[key].cars.append(car);groups[key].bounds=groups[key].bounds.merge(route.bounds)
	var meshes:Array[ArrayMesh]=[]
	for variant in range(4): meshes.append(vehicle_mesh(variant))
	for key in groups:
		var group:Dictionary=groups[key]
		var data:=MultiMesh.new();data.transform_format=MultiMesh.TRANSFORM_3D
		data.use_colors=true;data.use_custom_data=true;data.mesh=meshes[key.x];data.instance_count=group.cars.size()
		data.custom_aabb=group.bounds
		for i in range(data.instance_count):
			var car:Dictionary=group.cars[i]
			data.set_instance_transform(i,Transform3D(car.basis,car.origin))
			data.set_instance_color(i,car.color)
			data.set_instance_custom_data(i,Color(car.phase,car.speed,car.length,0.))
		var renderer:=MultiMeshInstance3D.new();renderer.name="AirTraffic%d_%d_%d"%[key.x,key.y,key.z]
		renderer.multimesh=data;renderer.material_override=material;renderer.layers=2
		renderer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;renderer.set_meta("gi_dynamic",true);renderer.set_meta("air_traffic",true)
		parent.add_child(renderer);batches.append(data);renderers.append(renderer)

func animate(time:float)->void:
	clock=time;material.set_shader_parameter("traffic_time",time)

func car_frame(car:Dictionary)->Transform3D:
	return Transform3D(car.basis,car.origin+car.basis.z*fposmod(car.phase+clock*car.speed,car.length))

func trace(from:Vector3,to:Vector3,radius:float)->Dictionary:
	var seen:Dictionary={};var nearest:Dictionary={};var best:=INF
	var query:=AABB(from,Vector3.ZERO).expand(to).grow(radius)
	for cell in Cells.cells(query):
		for id in buckets.get(cell,[]):
			if seen.has(id): continue
			seen[id]=true
			var route:Dictionary=routes[id]
			if not route.bounds.intersects(query): continue
			# Cars keep their lane spacing. Invert travel to find only the slots
			# covered by this sweep, including the two neighbours for phase jitter.
			var origin_x:float=route.start.x+(route.length if route.direction<0. else 0.)
			var a:float=(query.position.x-origin_x)*route.direction-clock*route.speed-route.phase
			var b:float=(query.end.x-origin_x)*route.direction-clock*route.speed-route.phase
			var first:=floori(minf(a,b)/route.spacing)-1
			var last:=ceili(maxf(a,b)/route.spacing)+1
			for offset in range(mini(last-first+1,route.cars.size())):
				var index:int=route.cars[posmod(first+offset,route.cars.size())]
				var car:Dictionary=cars[index];var frame:=car_frame(car)
				var size:Vector3=SIZES[car.variant]
				var bounds:=AABB(Vector3(-size.x*.5,-.6,-size.z*.5),size).grow(radius)
				if not (frame*bounds).intersects(query): continue
				var contact:Dictionary=load("res://src/obstacles.gd").box_contact(frame.affine_inverse(),bounds,from,to)
				if not contact.is_empty():
					var distance:=from.distance_squared_to(contact.position)
					if distance<best: best=distance;nearest=contact
	return nearest
