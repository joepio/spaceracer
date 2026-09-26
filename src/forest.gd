extends RefCounted
## Seeded giant-tree archipelago. Spatially batched meshes and swept-road clearance.
const Cells=preload("res://src/city_layout.gd")
const Batch=preload("res://src/scenery.gd")
var layout:Dictionary={"billboards":[]}
var traffic:=MultiMesh.new()
var animation_time:=0.
var local_lights:Array[Light3D]=[]
var reflection_boxes:Array[Dictionary]=[]
var probes:Array[ReflectionProbe]=[]
var trees:Array[Dictionary]=[]
var plants:Array[AABB]=[]
var corridor:Dictionary={}
var water:ShaderMaterial
var foliage:ShaderMaterial
var water_level:float

func clear(bounds:AABB)->bool:
	for cell in Cells.cells(bounds):
		for road:AABB in corridor.get(cell,[]):
			if road.intersects(bounds): return false
	return true

static func triangle(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,color:Color)->void:
	var normal:Vector3=(b-a).cross(c-a).normalized()
	for point in [a,b,c]:
		surface.set_color(color);surface.set_normal(normal);surface.add_vertex(point)

static func branch(surface:SurfaceTool,a:Vector3,b:Vector3,thickness:float)->void:
	var axis:Vector3=(b-a).normalized()
	var right:=axis.cross(Vector3.FORWARD).normalized()
	if right.length_squared()<.1: right=Vector3.RIGHT
	var forward:=axis.cross(right).normalized()
	for ring in range(6):
		var q:float=ring/6.
		var r:float=(ring+1)/6.
		var bend:=right*.012*sin(q*PI)
		var next_bend:=right*.012*sin(r*PI)
		for side in range(9):
			var angle:float=side*TAU/9.
			var next:float=(side+1)*TAU/9.
			var v:=right*cos(angle)+forward*sin(angle)
			var w:=right*cos(next)+forward*sin(next)
			var p0:=a.lerp(b,q)+bend+v*thickness*lerpf(1.,.2,q)
			var p1:=a.lerp(b,q)+bend+w*thickness*lerpf(1.,.2,q)
			var p2:=a.lerp(b,r)+next_bend+w*thickness*lerpf(1.,.2,r)
			var p3:=a.lerp(b,r)+next_bend+v*thickness*lerpf(1.,.2,r)
			triangle(surface,p0,p1,p2,Color.WHITE);triangle(surface,p0,p2,p3,Color.WHITE)

static func model(variant:int)->Dictionary:
	var rng:=RandomNumberGenerator.new();rng.seed=1841+variant*713
	var wood:=SurfaceTool.new();wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves:=SurfaceTool.new();leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bounds:Array[AABB]=[]
	branch(wood,Vector3.ZERO,Vector3(.025,1.,.01),.034)
	bounds.append(AABB(Vector3(-.055,0,-.055),Vector3(.13,1.03,.13)))
	# Buttress roots give the trunks a grounded silhouette.
	for i in range(6):
		var direction:=Vector3(cos(i*TAU/6.),0.,sin(i*TAU/6.))
		branch(wood,direction*.095,Vector3.UP*.19,.018)
	bounds.append(AABB(Vector3(-.12,0,-.12),Vector3(.24,.22,.24)))
	for i in range(9):
		var a:=rng.randf()*TAU
		var level:=.43+i*.057
		var spread:float=(.19 if variant==0 else (.14 if variant==1 else .23))*(1.-i*.045)
		var end:=Vector3(cos(a)*spread,level+.09,sin(a)*spread)
		var start:=Vector3(.012,level-.045,0.)
		branch(wood,start,end,.012)
		bounds.append(AABB(start,Vector3.ZERO).expand(end).grow(.027))
		# Hundreds of individually folded leaves, rather than solid green spheres.
		var crown:=Vector3(.105,.048,.105)*(1.15 if variant==2 else 1.)
		bounds.append(AABB(end-crown*1.25,crown*2.5).grow(.015))
		for leaf in range(92):
			var azimuth:=rng.randf()*TAU
			var radius:=sqrt(rng.randf())
			var center:=end+Vector3(cos(azimuth)*crown.x*radius,rng.randf_range(-1,1)*crown.y*(1.-radius*.6),sin(azimuth)*crown.z*radius)
			var across:=Vector3(cos(azimuth),rng.randf_range(-.2,.2),sin(azimuth))*.019
			var along:=Vector3(-sin(azimuth),rng.randf_range(-.3,.3),cos(azimuth))*.03
			var middle:=center+Vector3.UP*.005
			var color:=Color(.65+rng.randf()*.35,.7+rng.randf()*.3,.6+rng.randf()*.4,1.)
			triangle(leaves,center-along,center-across,middle,color)
			triangle(leaves,center-across,center+along,middle,color)
			triangle(leaves,center+along,center+across,middle,color)
			triangle(leaves,center+across,center-along,middle,color)
	return {"wood":wood.commit(),"leaves":leaves.commit(),"bounds":bounds}

static func fern_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for frond in range(9):
		var angle:=frond*TAU/9.
		var along:=Vector3(cos(angle),0.,sin(angle))
		var across:=Vector3(-sin(angle),0.,cos(angle))
		for row in range(1,13):
			var t:float=row/13.
			var center:=along*t+Vector3.UP*(.13+sin(t*PI*.9)*.65)
			for side in [-1.,1.]:
				var tip:Vector3=center+across*side*sin(t*PI)*.3+along*.13
				triangle(surface,center-along*.055,tip,center+along*.055,Color(.7,1.,.7))
	return surface.commit()

func build(parent:Node3D,race:RefCounted)->void:
	var track:RefCounted=race.track
	water_level=track.water_level
	for i in range(track.nodes.size()):
		var a:Dictionary=track.nodes[i]
		var b:Dictionary=track.nodes[(i+1)%track.nodes.size()]
		var bounds:=AABB(a.p,Vector3.ZERO).expand(b.p).grow(maxf(a.width,b.width)+20.)
		if a.feature in ["jump","flight"]: bounds=bounds.grow(35.).expand(a.p+Vector3.UP*140.)
		for cell in Cells.cells(bounds):
			if not corridor.has(cell): corridor[cell]=[]
			corridor[cell].append(bounds)
	var bark:=ShaderMaterial.new();bark.shader=load("res://src/forest_bark.gdshader")
	foliage=ShaderMaterial.new();foliage.shader=load("res://src/forest_leaves.gdshader")
	var rock:=ShaderMaterial.new();rock.shader=load("res://src/forest_rock.gdshader")
	var models:Array=[]
	for i in range(3): models.append(model(i))
	var groups:Dictionary={}
	var islands:Dictionary={}
	var undergrowth:Dictionary={}
	var rng:=RandomNumberGenerator.new();rng.seed=track.seed_value+80441
	for x in range(-17,18):
		for z in range(-17,18):
			if rng.randf()<.24: continue
			var height:=rng.randf_range(260.,520.)
			var variant:=rng.randi_range(0,2)
			var center:=Vector3(x*145.+rng.randf_range(-35.,35.),water_level+8.,z*145.+rng.randf_range(-35.,35.))
			var transform:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*height),center)
			var safe:=true
			var world_bounds:Array[AABB]=[]
			for local:AABB in models[variant].bounds:
				var bounds:AABB=transform*local
				world_bounds.append(bounds)
				if not clear(bounds): safe=false;break
			var island:=AABB(center-Vector3(height*.14,30.,height*.14),Vector3(height*.28,42.,height*.28))
			if not safe or not clear(island): continue
			var tint:=Color.from_hsv(rng.randf_range(.25,.37),rng.randf_range(.40,.65),rng.randf_range(.42,.72))
			trees.append({"transform":transform,"variant":variant,"bounds":world_bounds,"height":height,"island":island})
			var key:=Vector3i(floori(center.x/600.),variant,floori(center.z/600.))
			if not groups.has(key): groups[key]=[]
			groups[key].append({"transform":transform,"color":tint})
			var tile:=Vector2i(key.x,key.z)
			if not islands.has(tile): islands[tile]=[]
			islands[tile].append(Transform3D(Basis.IDENTITY.scaled(island.size),island.get_center()))
			for plant in range(5):
				var angle:float=plant*TAU/5.+rng.randf()
				var position:=center+Vector3(cos(angle)*height*.065,4.,sin(angle)*height*.065)
				var size:=rng.randf_range(8.,15.)
				var plant_bounds:=AABB(position-Vector3(size,0.,size),Vector3(size*2.,size,size*2.)).grow(1.)
				if not clear(plant_bounds): continue
				plants.append(plant_bounds)
				if not undergrowth.has(tile): undergrowth[tile]=[]
				undergrowth[tile].append(Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*size),position))
	for key in groups:
		var records:Array=groups[key]
		for part in ["wood","leaves"]:
			var data:=Batch.batch(parent,models[key.y][part],bark if part=="wood" else foliage,records.size())
			for i in range(records.size()):
				data.set_instance_transform(i,records[i].transform)
				data.set_instance_color(i,records[i].color if part=="leaves" else Color.WHITE)
	var island_mesh:=SphereMesh.new();island_mesh.radius=.5;island_mesh.height=1.;island_mesh.radial_segments=16;island_mesh.rings=8
	for tile in islands:
		var data:=Batch.batch(parent,island_mesh,rock,islands[tile].size())
		for i in range(islands[tile].size()): data.set_instance_transform(i,islands[tile][i]);data.set_instance_color(i,Color.WHITE)
	var fern:=fern_mesh()
	for tile in undergrowth:
		var data:=Batch.batch(parent,fern,foliage,undergrowth[tile].size())
		for i in range(undergrowth[tile].size()): data.set_instance_transform(i,undergrowth[tile][i]);data.set_instance_color(i,Color("8ac49e"))
	water=ShaderMaterial.new();water.shader=load("res://src/forest_water.gdshader")
	var lake:=MeshInstance3D.new();var plane:=PlaneMesh.new()
	plane.size=Vector2(14000.,14000.);plane.subdivide_width=80;plane.subdivide_depth=80
	lake.mesh=plane;lake.position.y=water_level;lake.material_override=water;lake.layers=4
	lake.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(lake)
	for fraction in [.03,.35,.72]:
		var n:Dictionary=track.sample(track.length*fraction)
		var probe:=ReflectionProbe.new()
		probe.position=n.p+Vector3.UP*25.;probe.size=Vector3(950.,700.,950.)
		probe.max_distance=1400.;probe.blend_distance=160.;probe.intensity=1.1
		probe.cull_mask=1;probe.reflection_mask=6;probe.box_projection=true
		probe.update_mode=ReflectionProbe.UPDATE_ONCE
		parent.add_child(probe);probes.append(probe)
	animate(0.)

func animate(time:float)->void:
	animation_time=time
	water.set_shader_parameter("race_time",time)
	foliage.set_shader_parameter("race_time",time)
