extends RefCounted
## Seeded desert: dune sea, sandstone canyons, hoodoos, natural arches and a
## sandworm. Spatially batched meshes and swept-road clearance like the forest.
const Cells=preload("res://src/city_layout.gd")
const Terrain=preload("res://src/desert_terrain.gd")
const Batch=preload("res://src/scenery.gd")
const Sandworm=preload("res://src/sandworm.gd")
const SUN_ROTATION:=Vector3(-30,-62,0)
var layout:Dictionary={"billboards":[]}
var traffic:=MultiMesh.new()
var animation_time:=0.
var local_lights:Array[Light3D]=[]
var reflection_boxes:Array[Dictionary]=[]
var probes:Array[ReflectionProbe]=[]
var corridor:Dictionary={}
var rocks:Array[Dictionary]=[]
var cacti:Array[Dictionary]=[]
var arches:Array[Dictionary]=[]
var terrain:RefCounted
var ground:ShaderMaterial
var rock_material:ShaderMaterial
var cactus_material:ShaderMaterial
var worm:RefCounted
var track:RefCounted
var node_cells:Dictionary={}
const NODE_CELL:=150.

func clear(bounds:AABB)->bool:
	for cell in Cells.cells(bounds):
		for road:AABB in corridor.get(cell,[]):
			if road.intersects(bounds): return false
	return true

## Exact check against the swept course: true when a sphere at `point` keeps
## the full road width and a tall flight envelope above it free.
func course_clear(point:Vector3,radius:float,headroom:float=60.)->bool:
	var cell:=Vector2i(floori(point.x/NODE_CELL),floori(point.z/NODE_CELL))
	var reach_cells:=1+floori(radius/NODE_CELL)
	for cx in range(cell.x-reach_cells,cell.x+reach_cells+1):
		for cz in range(cell.y-reach_cells,cell.y+reach_cells+1):
			for index in node_cells.get(Vector2i(cx,cz),[]):
				if not node_clear(track.nodes[index],point,radius,headroom): return false
	return true

func node_clear(n:Dictionary,point:Vector3,radius:float,headroom:float)->bool:
	var flat:=Vector2(point.x-n.p.x,point.z-n.p.z).length()
	var reach:float=n.width+float(n.get("split_gap",0.))+radius+12.
	if n.feature in ["jump","flight"]: reach+=40.
	if flat>reach: return true
	return not (point.y+radius>n.p.y-30. and point.y-radius<n.p.y+headroom)

static func profile(kind:int,t:float)->Vector2:
	if kind<2:
		# Stacked drums of soft rock under a hard, overhanging cap stone.
		var waist:=.09+.035*sin(t*TAU*(2.+kind*.5)+kind)
		var base:=.17*(1.-smoothstep(0.,.25,t))
		var cap_stone:=.09*smoothstep(.8,.88,t)*(1.-smoothstep(.95,1.,t))
		return Vector2(waist+base+cap_stone,t)
	return Vector2(sin(PI*(.08+t*.84))*.5,t*.7-.15)

static func rock_mesh(kind:int)->ArrayMesh:
	# Jittered, flat-shaded rings read as wind-carved sandstone, not a cylinder.
	var rng:=RandomNumberGenerator.new();rng.seed=7100+kind
	var rings:=14 if kind<2 else 6
	var sides:=9 if kind<2 else 8
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var points:Array[PackedVector3Array]=[]
	for ring in range(rings+1):
		var shape:=profile(kind,ring/float(rings))
		var row:=PackedVector3Array()
		var twist:=rng.randf()*TAU
		for side in range(sides):
			var angle:=side*TAU/sides+twist*.08
			var r:float=shape.x*rng.randf_range(.82,1.12)
			row.append(Vector3(cos(angle)*r,shape.y+rng.randf_range(-.008,.008),sin(angle)*r))
		points.append(row)
	for ring in range(rings):
		for side in range(sides):
			var a:=points[ring][side];var b:=points[ring][(side+1)%sides]
			var c:=points[ring+1][side];var d:=points[ring+1][(side+1)%sides]
			for vertex in [a,c,b,b,c,d]:
				surface.set_color(Color.WHITE);surface.add_vertex(vertex)
	var top:=Vector3(0.,profile(kind,1.).y+.01,0.)
	for side in range(sides):
		for vertex in [points[rings][side],top,points[rings][(side+1)%sides]]:
			surface.set_color(Color.WHITE);surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()

static func cactus_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	limb(surface,[Vector3(0,0,0),Vector3(0,1.,0)],.055)
	limb(surface,[Vector3(.04,.42,0),Vector3(.2,.44,0),Vector3(.23,.52,0),Vector3(.23,.78,0)],.04)
	limb(surface,[Vector3(-.04,.55,0),Vector3(-.17,.56,0),Vector3(-.19,.63,0),Vector3(-.19,.84,0)],.036)
	return surface.commit()

static func limb(surface:SurfaceTool,path:Array,radius:float)->void:
	# A smooth swept tube with a domed tip, colored a dusty sage green.
	var points:=PackedVector3Array()
	for i in range(path.size()-1):
		for step in range(6):
			points.append((path[i] as Vector3).lerp(path[i+1],step/6.))
	points.append(path[-1])
	var tip:Vector3=path[-1]
	for step in range(1,5):
		var a:=step/4.*PI*.5
		points.append(tip+Vector3.UP*sin(a)*radius*.9)
	const SIDES:=12
	for i in range(points.size()-1):
		var forward:Vector3=(points[i+1]-points[i]).normalized()
		var r0:=radius*(cos(clampf(float(i-(points.size()-5))/4.,0.,1.)*PI*.5) if i>=points.size()-5 else 1.)
		var r1:=radius*(cos(clampf(float(i+1-(points.size()-5))/4.,0.,1.)*PI*.5) if i+1>=points.size()-5 else 1.)
		var x:=forward.cross(Vector3.FORWARD if absf(forward.z)<.9 else Vector3.RIGHT).normalized()
		var y:=forward.cross(x)
		for side in range(SIDES):
			var n0:=x*cos(side*TAU/SIDES)+y*sin(side*TAU/SIDES)
			var n1:=x*cos((side+1)*TAU/SIDES)+y*sin((side+1)*TAU/SIDES)
			for vertex in [[points[i],n0,r0],[points[i+1],n0,r1],[points[i],n1,r0],[points[i],n1,r0],[points[i+1],n0,r1],[points[i+1],n1,r1]]:
				surface.set_color(Color("6c8a4f"));surface.set_normal(vertex[1])
				surface.add_vertex(vertex[0]+vertex[1]*vertex[2])

func build(parent:Node3D,race:RefCounted)->void:
	track=race.track
	for i in range(track.nodes.size()):
		var p:Vector3=track.nodes[i].p
		var key:=Vector2i(floori(p.x/NODE_CELL),floori(p.z/NODE_CELL))
		if not node_cells.has(key): node_cells[key]=[]
		node_cells[key].append(i)
	for i in range(track.nodes.size()):
		var a:Dictionary=track.nodes[i]
		var b:Dictionary=track.nodes[(i+1)%track.nodes.size()]
		var bounds:=AABB(a.p,Vector3.ZERO).expand(b.p).grow(maxf(a.width,b.width)+24.)
		if a.feature in ["jump","flight"]: bounds=bounds.grow(35.).expand(a.p+Vector3.UP*140.)
		for cell in Cells.cells(bounds):
			if not corridor.has(cell): corridor[cell]=[]
			corridor[cell].append(bounds)
	terrain=Terrain.new(track)
	ground=terrain.build(parent,Basis.from_euler(SUN_ROTATION*PI/180.).z)
	if track.obstacles: track.obstacles.terrain=terrain
	rock_material=ShaderMaterial.new();rock_material.shader=load("res://src/desert_rock.gdshader")
	cactus_material=ShaderMaterial.new();cactus_material.shader=load("res://src/desert_rock.gdshader")
	cactus_material.set_shader_parameter("vegetation",true)
	var rng:=RandomNumberGenerator.new();rng.seed=track.seed_value+51713
	var meshes:Array[Mesh]=[rock_mesh(0),rock_mesh(1),rock_mesh(2),rock_mesh(3)]
	var groups:Dictionary={}
	var cactus_groups:Dictionary={}
	for x in range(-24,25):
		for z in range(-24,25):
			var center:=Vector3(x*130.+rng.randf_range(-60.,60.),0.,z*130.+rng.randf_range(-60.,60.))
			if center.length()>3300.: continue
			center.y=terrain.height_at(center.x,center.z)
			var normal:Vector3=terrain.normal_at(center.x,center.z)
			var roll:=rng.randf()
			var variant:int
			var transform:Transform3D
			if roll<.16 and normal.y>.86:
				# Lone hoodoo spires, 35-120 m, rooted below the sand line.
				variant=rng.randi_range(0,1)
				var height:=rng.randf_range(35.,120.)
				var girth:=height*rng.randf_range(.75,1.25)
				transform=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(girth,height,girth*rng.randf_range(.8,1.2))),center-Vector3.UP*3.)
			elif roll<.5:
				variant=rng.randi_range(2,3)
				var size:=rng.randf_range(6.,26.)
				transform=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).rotated(Vector3.RIGHT,rng.randf_range(-.2,.2)).scaled(Vector3(size*rng.randf_range(.9,1.5),size,size*rng.randf_range(.8,1.3))),center)
			elif roll<.78 and normal.y>.93:
				for k in range(rng.randi_range(1,4)):
					var spot:=center+Vector3(rng.randf_range(-45.,45.),0.,rng.randf_range(-45.,45.))
					spot.y=terrain.height_at(spot.x,spot.z)-.3
					var height:=rng.randf_range(9.,17.)
					var plant:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*height),spot)
					var bounds:=AABB(spot-Vector3(height*.25,0.,height*.25),Vector3(height*.5,height,height*.5))
					if not clear(bounds): continue
					cacti.append({"transform":plant,"bounds":bounds})
					if track.obstacles: track.obstacles.add_box(plant,AABB(Vector3(-.055,0.,-.055),Vector3(.11,1.,.11)))
					var key:=Vector2i(floori(spot.x/900.),floori(spot.z/900.))
					if not cactus_groups.has(key): cactus_groups[key]=[]
					cactus_groups[key].append(plant)
				continue
			else: continue
			var world_bounds:AABB=transform*meshes[variant].get_aabb()
			if not clear(world_bounds.grow(4.)): continue
			rocks.append({"transform":transform,"variant":variant,"bounds":world_bounds})
			if track.obstacles:
				var core:AABB=meshes[variant].get_aabb()
				track.obstacles.add_box(transform,AABB(core.position*.75,core.size*.75))
			var key:=Vector3i(floori(center.x/900.),variant,floori(center.z/900.))
			if not groups.has(key): groups[key]=[]
			var shade:=rng.randf_range(.88,1.06)
			groups[key].append({"transform":transform,"color":Color(shade,shade*rng.randf_range(.95,1.02),shade*rng.randf_range(.9,1.))})
	for key in groups:
		var records:Array=groups[key]
		var data:=Batch.batch(parent,meshes[key.y],rock_material,records.size())
		for i in range(records.size()):
			data.set_instance_transform(i,records[i].transform)
			data.set_instance_color(i,records[i].color)
	var cactus:=cactus_mesh()
	for key in cactus_groups:
		var data:=Batch.batch(parent,cactus,cactus_material,cactus_groups[key].size())
		for i in range(cactus_groups[key].size()):
			data.set_instance_transform(i,cactus_groups[key][i]);data.set_instance_color(i,Color.WHITE)
	build_arches(parent)
	worm=Sandworm.new()
	worm.build(parent,race,self)
	for fraction in [.03,.35,.72]:
		var n:Dictionary=track.sample(track.length*fraction)
		var probe:=ReflectionProbe.new()
		probe.position=n.p+Vector3.UP*25.;probe.size=Vector3(950.,700.,950.)
		probe.max_distance=1400.;probe.blend_distance=160.;probe.intensity=1.
		probe.cull_mask=1;probe.reflection_mask=6;probe.box_projection=true
		probe.update_mode=ReflectionProbe.UPDATE_ONCE
		parent.add_child(probe);probes.append(probe)
	animate(0.)

func eligible(n:Dictionary)->bool:
	return n.feature in ["ribbon","open"] and not n.loop and n.split_gap<.01 and n.get("shape_angle",0.)<.001 and absf(n.slope)<.2

func build_arches(parent:Node3D)->void:
	# Natural sandstone arches span the course: the road threads through rock.
	var rng:=RandomNumberGenerator.new();rng.seed=track.seed_value+51811
	var count:int=track.nodes.size()
	var start:=rng.randi_range(0,count-1)
	var last:=-INF
	for k in range(0,count,4):
		if arches.size()>=4: break
		var index:int=(start+k)%count
		var distance:float=index*track.step
		if distance-last<track.length*.12 and arches.size()>0: continue
		var n:Dictionary=track.nodes[index]
		if not eligible(n) or absf(n.curve)>.007: continue
		if not track.jump_at(distance,400.).is_empty(): continue
		var in_basin:=false
		for center in terrain.basins:
			if absf(fposmod(distance-center+track.length*.5,track.length)-track.length*.5)<terrain.BASIN: in_basin=true
		if in_basin: continue
		var thickness:=rng.randf_range(24.,32.)
		var depth:=rng.randf_range(34.,48.)
		var half_span:float=n.width+34.+thickness*.5
		var crown:=rng.randf_range(72.,90.)+thickness*.5
		var arch:=arch_data(n,half_span,crown,thickness,depth)
		var ok:=true
		for sample:Dictionary in arch.samples:
			if not course_clear(sample.position,sample.radius,crown-thickness*.5-6.): ok=false;break
		if not ok: continue
		arches.append(arch)
		last=distance
		var instance:=MeshInstance3D.new();instance.name="SandstoneArch"
		instance.mesh=arch.mesh;instance.material_override=rock_material
		parent.add_child(instance)
		if track.obstacles:
			for sample:Dictionary in arch.samples:
				track.obstacles.add_box(Transform3D(sample.basis.scaled_local(Vector3(sample.radius*1.4,sample.radius*1.4,depth*.8)),sample.position))

func arch_data(n:Dictionary,half_span:float,crown:float,thickness:float,depth:float)->Dictionary:
	var across:Vector3=-n.frame.x;across.y=0.;across=across.normalized()
	var along:=across.cross(Vector3.UP).normalized()
	var origin:Vector3=n.p
	var left:Vector3=origin-across*half_span;var right:=origin+across*half_span
	var ground_left:float=terrain.height_at(left.x,left.z)-14.
	var ground_right:float=terrain.height_at(right.x,right.z)-14.
	var spring:=origin.y+18.
	var path:=PackedVector3Array()
	# Leg, elliptical span, leg: one continuous centreline.
	for i in range(7): path.append(left+Vector3.UP*(lerpf(ground_left,spring,i/6.)-origin.y))
	for i in range(1,40):
		var theta:=PI-PI*i/40.
		# A squared-off superellipse: broad shoulders keep the whole road open.
		var lift:=pow(1.-pow(absf(cos(theta)),3.5),1./3.5)
		path.append(origin+across*cos(theta)*half_span+Vector3.UP*(spring-origin.y+(crown-18.)*lift))
	for i in range(7): path.append(right+Vector3.UP*(lerpf(spring,ground_right,i/6.)-origin.y))
	var rng:=RandomNumberGenerator.new();rng.seed=int(absf(origin.x*13.+origin.z*7.))
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	const SIDES:=10
	var rings:Array[PackedVector3Array]=[]
	var samples:Array[Dictionary]=[]
	for i in range(path.size()):
		var tangent:=(path[mini(i+1,path.size()-1)]-path[maxi(i-1,0)]).normalized()
		var normal:=along.cross(tangent).normalized()
		var height:=clampf((path[i].y-spring)/(crown-18.),0.,1.)
		# Thick, flared legs; a thinner, weathered lintel across the top.
		var r:=thickness*.5*lerpf(1.45,.9,height)
		var ring:=PackedVector3Array()
		for side in range(SIDES):
			var angle:=side*TAU/SIDES
			var jitter:=rng.randf_range(.85,1.15)
			ring.append(path[i]+normal*cos(angle)*r*jitter+along*sin(angle)*depth*.5*jitter)
		rings.append(ring)
		if i%2==0: samples.append({"position":path[i],"radius":maxf(r,depth*.25),"basis":Basis(normal,tangent,along)})
	for i in range(path.size()-1):
		for side in range(SIDES):
			var a:=rings[i][side];var b:=rings[i][(side+1)%SIDES]
			var c:=rings[i+1][side];var d:=rings[i+1][(side+1)%SIDES]
			for vertex in [a,b,c,b,d,c]:
				surface.set_color(Color.WHITE);surface.add_vertex(vertex)
	surface.generate_normals()
	return {"mesh":surface.commit(),"samples":samples,"origin":origin,"crown":crown,"half_span":half_span}

func animate(time:float)->void:
	animation_time=time
	if worm: worm.animate(time)
