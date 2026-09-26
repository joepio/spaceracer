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

static func branch(surface:SurfaceTool,a:Vector3,b:Vector3,thickness:float,segments:int=3)->void:
	var axis:Vector3=(b-a).normalized()
	var right:=axis.cross(Vector3.FORWARD).normalized()
	if right.length_squared()<.1: right=Vector3.RIGHT
	var forward:=axis.cross(right).normalized()
	for ring in range(segments):
		var q:float=ring/float(segments)
		var r:float=(ring+1)/float(segments)
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
			for vertex in [[p0,v],[p2,w],[p1,w],[p0,v],[p3,v],[p2,w]]:
				surface.set_color(Color.WHITE)
				surface.set_normal(vertex[1])
				surface.add_vertex(vertex[0])

static func leaf_card(surface:SurfaceTool,center:Vector3,across:Vector3,along:Vector3,cell:int,color:Color)->void:
	# Godot front faces are clockwise. Leaf tops must match the card plane;
	# radial crown normals can point down and illuminate the visible underside.
	var normal:=along.cross(across).normalized()
	var offset:=Vector2(cell%3,cell/3)*Vector2(1./3.,.5)
	var points:=[center-across-along,center+across-along,center+across+along,center-across+along]
	var uvs:=[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
	for index in [0,1,2,0,2,3]:
		surface.set_color(color)
		surface.set_normal(normal)
		surface.set_uv(offset+(uvs[index]*.96+Vector2.ONE*.02)*Vector2(1./3.,.5))
		surface.add_vertex(points[index])

static func model(variant:int,low_detail:bool=false)->Dictionary:
	var rng:=RandomNumberGenerator.new();rng.seed=1841+variant*713
	var wood:=SurfaceTool.new();wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves:=SurfaceTool.new();leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bounds:Array[AABB]=[]
	var segments:=1 if low_detail else 3
	var lean:=Vector3(rng.randf_range(-.06,.06),1.,rng.randf_range(-.04,.04))
	branch(wood,Vector3.ZERO,lean,.024 if variant==4 else .035,segments)
	bounds.append(AABB(Vector3(-.05,0,-.05),Vector3(.1,.1,.1)).expand(lean).grow(.025))
	for i in range(6):
		var direction:=Vector3(cos(i*TAU/6.),0.,sin(i*TAU/6.))
		branch(wood,direction*.095,Vector3.UP*.19,.018,segments)
	bounds.append(AABB(Vector3(-.12,0,-.12),Vector3(.24,.22,.24)))
	var spread:float=[.25,.12,.32,.20,.15,.29][variant]
	var count:int=[13,14,12,14,11,13][variant]
	for i in range(count):
		var t:float=i/float(count-1)
		var a:=i*2.399+rng.randf_range(-.45,.45)
		var level:=lerpf(.38 if variant==1 else .54,1.,t)
		if variant==2: level=lerpf(.77,1.,t)
		var radial:=spread*pow(1.-t,.55)*rng.randf_range(.75,1.2)
		var end:=lean*level+Vector3(cos(a)*radial,rng.randf_range(-.015,.04),sin(a)*radial)
		var start:=lean*(level-.13)
		branch(wood,start,end,.010 if variant==4 else .014,segments)
		bounds.append(AABB(start,Vector3.ZERO).expand(end).grow(.027))
		var crown:=Vector3(.11,.085,.11)*rng.randf_range(.8,1.2)
		if variant==2: crown*=Vector3(1.25,.7,1.25)
		if variant==1: crown*=Vector3(.75,.8,.75)
		bounds.append(AABB(end-crown-Vector3.ONE*.045,(crown+Vector3.ONE*.045)*2.))
		# A shaded interior supports dense crowns without filling their volume
		# with hundreds more alpha-tested cards. The outer leaves break its edge.
		for ring in range(4):
			for side in range(8):
				var vertices:Array[Vector3]=[]
				for pair in [Vector2(side,ring),Vector2(side+1,ring),Vector2(side+1,ring+1),Vector2(side,ring+1)]:
					var az:float=pair.x*TAU/8.
					var el:float=pair.y*PI/4.
					vertices.append(end+Vector3(cos(az)*sin(el),cos(el),sin(az)*sin(el))*crown*.72)
				for index in [0,2,1,0,3,2]:
					leaves.set_color(Color(.8,.9,.8,0.))
					leaves.set_normal((vertices[index]-end).normalized())
					leaves.set_uv(Vector2(side/8.,ring/4.))
					leaves.add_vertex(vertices[index])
		for leaf in range(96):
			var azimuth:=rng.randf()*TAU
			var y:=rng.randf_range(-1.,1.)
			var radius:=pow(rng.randf(),.333)*sqrt(1.-y*y)
			var center:=end+Vector3(cos(azimuth)*crown.x*radius,y*crown.y,sin(azimuth)*crown.z*radius)
			var scale:=rng.randf_range(.65,1.35)
			var across:=Vector3(cos(azimuth),rng.randf_range(-.5,.5),sin(azimuth))*.016*scale
			var along:=Vector3(-sin(azimuth),rng.randf_range(-.65,.65),cos(azimuth))*.026*scale
			var color:=Color(rng.randf_range(.78,1.),rng.randf_range(.84,1.),rng.randf_range(.78,1.),1.)
			var cell:=rng.randi_range(0,5)
			if not low_detail or leaf%4==0: leaf_card(leaves,center,across,along,cell,color)
	leaves.generate_tangents()
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
	bark.set_shader_parameter("bark_color",load("res://assets/forest/Bark007_1K-JPG_Color.jpg"))
	foliage=ShaderMaterial.new();foliage.shader=load("res://src/forest_leaves.gdshader")
	foliage.set_shader_parameter("leaf_color",load("res://assets/forest/LeafSet014_1K-JPG_Color.jpg"))
	foliage.set_shader_parameter("leaf_mask",load("res://assets/forest/LeafSet014_1K-JPG_Opacity.jpg"))
	foliage.set_shader_parameter("leaf_normal",load("res://assets/forest/LeafSet014_1K-JPG_NormalGL.jpg"))
	understory=ShaderMaterial.new();understory.shader=load("res://src/forest_understory.gdshader")
	var rock:=ShaderMaterial.new();rock.shader=load("res://src/forest_rock.gdshader")
	var models:Array=[]
	var distant:Array=[]
	for i in range(6):
		models.append(model(i))
		distant.append(model(i,true))
	var groups:Dictionary={}
	var islands:Dictionary={}
	var undergrowth:Dictionary={}
	var rng:=RandomNumberGenerator.new();rng.seed=track.seed_value+80441
	for x in range(-17,18):
		for z in range(-17,18):
			if rng.randf()<.12: continue
			var age:=rng.randf()
			var height:=rng.randf_range(340.,650.) if age>.32 else (rng.randf_range(190.,340.) if age>.1 else rng.randf_range(80.,190.))
			var variant:=rng.randi_range(0,5)
			var center:=Vector3(x*145.+rng.randf_range(-62.,62.),water_level+8.,z*145.+rng.randf_range(-62.,62.))
			var transform:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(rng.randf_range(.72,1.35),1.,rng.randf_range(.72,1.35))*height),center)
			var safe:=true
			var world_bounds:Array[AABB]=[]
			for local:AABB in models[variant].bounds:
				var bounds:AABB=transform*local
				world_bounds.append(bounds)
				if not clear(bounds): safe=false;break
			var island:=AABB(center-Vector3(height*.14,30.,height*.14),Vector3(height*.28,42.,height*.28))
			if not safe or not clear(island): continue
			var tint:=Color(rng.randf_range(.76,1.05),rng.randf_range(.85,1.1),rng.randf_range(.7,.95))
			trees.append({"transform":transform,"variant":variant,"bounds":world_bounds,"height":height,"island":island})
			if track.obstacles:
				# Solid trunks, roots and branches collide; loose foliage remains flyable.
				for index in range(models[variant].bounds.size()):
					if index<2 or index%2==0: track.obstacles.add_box(transform,models[variant].bounds[index])
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
		for part in ["wood","leaves","distant","distant_wood"]:
			var is_wood:bool=part in ["wood","distant_wood"]
			var mesh:Mesh=distant[key.y]["wood" if is_wood else "leaves"] if part.begins_with("distant") else models[key.y][part]
			var data:=Batch.batch(parent,mesh,bark if is_wood else foliage,records.size())
			var renderer:=parent.get_child(parent.get_child_count()-1) as MultiMeshInstance3D
			if part.begins_with("distant"): renderer.visibility_range_begin=1200.
			else: renderer.visibility_range_end=1200.
			for i in range(records.size()):
				data.set_instance_transform(i,records[i].transform)
				data.set_instance_color(i,Color.WHITE if is_wood else records[i].color)
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
	foliage.set_shader_parameter("race_time",time)
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
