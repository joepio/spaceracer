extends RefCounted
## Seeded giant-tree archipelago. Spatially batched meshes and swept-road clearance.
const Cells=preload("res://src/city_layout.gd")
const Assets=preload("res://src/forest_assets.gd")
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
var understory:ShaderMaterial
var shore_image:Image
var water_level:float

func clear(bounds:AABB)->bool:
	for cell in Cells.cells(bounds):
		for road:AABB in corridor.get(cell,[]):
			if road.intersects(bounds): return false
	return true

static func triangle(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,color:Color)->void:
	var normal:Vector3=(c-a).cross(b-a).normalized()
	for point in [a,b,c]:
		surface.set_color(color);surface.set_normal(normal);surface.add_vertex(point)

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
	understory=ShaderMaterial.new();understory.shader=load("res://src/forest_understory.gdshader")
	var rock:=ShaderMaterial.new();rock.shader=load("res://src/forest_rock.gdshader")
	var models:Array=[]
	for i in range(Assets.PATHS.size()): models.append(Assets.model(i))
	var groups:Dictionary={}
	var islands:Dictionary={}
	var undergrowth:Dictionary={}
	var rng:=RandomNumberGenerator.new();rng.seed=track.seed_value+80441
	for x in range(-17,18):
		for z in range(-17,18):
			if rng.randf()<.12: continue
			var age:=rng.randf()
			var height:=rng.randf_range(340.,650.) if age>.32 else (rng.randf_range(190.,340.) if age>.1 else rng.randf_range(80.,190.))
			var variant:=0 if rng.randf()<.7 else 1
			var center:=Vector3(x*145.+rng.randf_range(-62.,62.),water_level+8.,z*145.+rng.randf_range(-62.,62.))
			var transform:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(rng.randf_range(.92,1.08),1.,rng.randf_range(.92,1.08))*height),center)
			var safe:=true
			var world_bounds:Array[AABB]=[]
			for local:AABB in models[variant].bounds:
				var bounds:AABB=transform*local
				world_bounds.append(bounds)
				if not clear(bounds): safe=false;break
			var island:=AABB(center-Vector3(height*.14,30.,height*.14),Vector3(height*.28,42.,height*.28))
			if not safe or not clear(island): continue
			var tint:=Color(rng.randf_range(.88,1.),rng.randf_range(.92,1.03),rng.randf_range(.86,.98))
			trees.append({"transform":transform,"variant":variant,"bounds":world_bounds,"height":height,"island":island})
			if track.obstacles:
				# Solid trunk sections collide; loose foliage remains flyable.
				for solid:AABB in models[variant].solids: track.obstacles.add_box(transform,solid)
				track.obstacles.add_box(Transform3D.IDENTITY,island)
			var key:=Vector3i(floori(center.x/800.),variant,floori(center.z/800.))
			if not groups.has(key): groups[key]=[]
			groups[key].append({"transform":transform,"color":tint})
			var tile:=Vector2i(key.x,key.z)
			if not islands.has(tile): islands[tile]=[]
			islands[tile].append(Transform3D(Basis.IDENTITY.scaled(island.size),island.get_center()))
			for plant in range(rng.randi_range(3,8)):
				var angle:float=plant*TAU/5.+rng.randf()
				var position:=center+Vector3(cos(angle)*height*.065,4.,sin(angle)*height*.065)
				var size:=rng.randf_range(2.,18.)
				var plant_bounds:=AABB(position-Vector3(size*1.4,0.,size*1.4),Vector3(size*2.8,size*1.4,size*2.8)).grow(1.)
				if not clear(plant_bounds): continue
				plants.append(plant_bounds)
				if not undergrowth.has(tile): undergrowth[tile]=[]
				undergrowth[tile].append(Transform3D(Basis(Vector3.UP,angle).scaled(Vector3(rng.randf_range(.65,1.3),rng.randf_range(.55,1.4),rng.randf_range(.65,1.3))*size),position))
	for key in groups:
		var records:Array=groups[key]
		for part:Dictionary in models[key.y].parts:
			var data:=Batch.batch(parent,part.mesh,part.material,records.size())
			var renderer:=parent.get_child(parent.get_child_count()-1) as MultiMeshInstance3D
			renderer.lod_bias=.45
			for i in range(records.size()):
				data.set_instance_transform(i,records[i].transform*part.transform)
				data.set_instance_color(i,records[i].color)
	var island_mesh:=SphereMesh.new();island_mesh.radius=.5;island_mesh.height=1.;island_mesh.radial_segments=16;island_mesh.rings=8
	for tile in islands:
		var data:=Batch.batch(parent,island_mesh,rock,islands[tile].size())
		for i in range(islands[tile].size()): data.set_instance_transform(i,islands[tile][i]);data.set_instance_color(i,Color.WHITE)
	var fern:=fern_mesh()
	for tile in undergrowth:
		var data:=Batch.batch(parent,fern,understory,undergrowth[tile].size())
		for i in range(undergrowth[tile].size()): data.set_instance_transform(i,undergrowth[tile][i]);data.set_instance_color(i,Color("8ac49e"))
	water=ShaderMaterial.new();water.shader=load("res://src/forest_water.gdshader")
	water.set_shader_parameter("shore_map",make_shore_map())
	var noise:=FastNoiseLite.new()
	noise.seed=7103;noise.frequency=.035;noise.fractal_octaves=3
	var ripples:=NoiseTexture2D.new()
	ripples.width=256;ripples.height=256;ripples.seamless=true
	ripples.as_normal_map=true;ripples.bump_strength=2.;ripples.generate_mipmaps=true;ripples.noise=noise
	water.set_shader_parameter("ripples",ripples)
	var lake:=MeshInstance3D.new();var plane:=PlaneMesh.new()
	plane.size=Vector2(14000.,14000.);plane.subdivide_width=128;plane.subdivide_depth=128
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
	understory.set_shader_parameter("race_time",time)

func make_shore_map()->ImageTexture:
	# Bake nearby island shallows once. No per-frame depth pass or CPU water simulation.
	const RES:=512
	const SPAN:=6000.
	shore_image=Image.create(RES,RES,false,Image.FORMAT_RF)
	shore_image.fill(Color(0,0,0,1))
	for tree in trees:
		var bounds:AABB=tree.island
		var center:=Vector2(bounds.get_center().x,bounds.get_center().z)
		var radius:=Vector2(bounds.size.x,bounds.size.z)*.5
		var lo:=Vector2i(((center-radius-Vector2.ONE*48.)/SPAN+Vector2.ONE*.5)*RES)
		var hi:=Vector2i(((center+radius+Vector2.ONE*48.)/SPAN+Vector2.ONE*.5)*RES)
		for y in range(maxi(0,lo.y),mini(RES,hi.y+1)):
			for x in range(maxi(0,lo.x),mini(RES,hi.x+1)):
				var point:Vector2=(Vector2(x,y)/RES-Vector2.ONE*.5)*SPAN
				var distance:float=((point-center)/radius).length()-1.
				var shore:=clampf(1.-distance*minf(radius.x,radius.y)/45.,0.,1.)
				if shore>shore_image.get_pixel(x,y).r: shore_image.set_pixel(x,y,Color(shore,0,0,1))
	shore_image.generate_mipmaps()
	return ImageTexture.create_from_image(shore_image)
