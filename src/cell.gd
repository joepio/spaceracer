extends RefCounted
## A seeded microscopic world. Shared meshes, spatial batches, and swept-road clearance.
const Cells=preload("res://src/city_layout.gd")
const Batch=preload("res://src/scenery.gd")
var layout:Dictionary={"billboards":[]}
var traffic:=MultiMesh.new()
var animation_time:=0.
var local_lights:Array[Light3D]=[]
var reflection_boxes:Array[Dictionary]=[]
var probes:Array[ReflectionProbe]=[]
var corridor:Dictionary={}
var specimens:Array[Dictionary]=[]
var walkers:Array[Dictionary]=[]
var groups:Dictionary={}
var bodies:MultiMesh
var legs:MultiMesh
var feet:MultiMesh
var obstacles:RefCounted
var membrane:ShaderMaterial
var sphere:SphereMesh
var rod:CylinderMesh
var tissue:ShaderMaterial

func clear(bounds:AABB)->bool:
	for tile in Cells.cells(bounds):
		for road:AABB in corridor.get(tile,[]):
			if road.intersects(bounds): return false
	return true

static func link(a:Vector3,b:Vector3,width:float)->Transform3D:
	var direction:Vector3=(b-a).normalized()
	var across:Vector3=direction.cross(Vector3.FORWARD if absf(direction.z)<.95 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(across,direction,across.cross(direction)).scaled_local(Vector3(width,a.distance_to(b),width)),(a+b)*.5)

static func tube(surface:SurfaceTool,points:PackedVector3Array,radius:float,color:Color,sides:int=7)->void:
	var rings:Array[PackedVector3Array]=[]
	for i in range(points.size()):
		var forward:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var x:Vector3=forward.cross(Vector3.UP if absf(forward.y)<.95 else Vector3.RIGHT).normalized()
		var y:Vector3=forward.cross(x)
		var normals:=PackedVector3Array()
		for side in range(sides): normals.append(x*cos(side*TAU/sides)+y*sin(side*TAU/sides))
		rings.append(normals)
	for i in range(points.size()-1):
		for side in range(sides):
			var n0:=rings[i][side];var n1:=rings[i][(side+1)%sides]
			var n2:=rings[i+1][side];var n3:=rings[i+1][(side+1)%sides]
			for vertex in [[points[i]+n0*radius,n0],[points[i+1]+n2*radius,n2],[points[i]+n1*radius,n1],
				[points[i+1]+n2*radius,n2],[points[i+1]+n3*radius,n3],[points[i]+n1*radius,n1]]:
				surface.set_color(color);surface.set_normal(vertex[1]);surface.add_vertex(vertex[0])

static func dna_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in range(2):
		var points:=PackedVector3Array()
		for i in range(145):
			var t:float=i/144.;var angle:=t*TAU*3.+strand*PI
			points.append(Vector3(cos(angle)*.115,t-.5,sin(angle)*.115))
		tube(surface,points,.016,Color("55dbcd") if strand==0 else Color("f1a79d"),8)
	for i in range(37):
		var t:float=i/36.;var angle:=t*TAU*3.
		var edge:=Vector3(cos(angle)*.115,0.,sin(angle)*.115)
		var center:=Vector3(0,t-.5,0)
		tube(surface,PackedVector3Array([center-edge,center]),.008,Color("c492e0") if i%2==0 else Color("edbf74"),6)
		tube(surface,PackedVector3Array([center,center+edge]),.008,Color("edbf74") if i%2==0 else Color("c492e0"),6)
	return surface.commit()

static func protein_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points:=PackedVector3Array()
	for i in range(201):
		var t:=TAU*i/200.
		var r:=.29+.105*cos(3.*t)
		points.append(Vector3(r*cos(2.*t),sin(3.*t)*.16,r*sin(2.*t)))
	tube(surface,points,.04,Color.WHITE,9)
	# A folded alpha helix threads through the knot rather than a plain ball.
	points=PackedVector3Array()
	for i in range(81):
		var t:=i/80.
		points.append(Vector3((t-.5)*.55,cos(t*TAU*6.)*.075+.16,sin(t*TAU*6.)*.075))
	tube(surface,points,.025,Color("f4cc9d"),7)
	return surface.commit()

static func cristae_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fold in range(9):
		var points:=PackedVector3Array()
		var z:float=(fold-4)*.085
		var width:=sqrt(1.-pow(z/.53,2.))
		for i in range(25):
			var a:=PI*i/24.
			var x:=cos(a)*.43*width
			var fold_z:=z+sin(a*3.)*.025
			points.append(Vector3(x,sqrt(maxf(.001,.25-x*x-fold_z*fold_z))+.009,fold_z))
		tube(surface,points,.024,Color("ffd49a"),6)
	return surface.commit()

static func sheet_point(a:float,v:float,layer:int)->Vector3:
	var r:float=.12+v*(.28+sin(a*3.+layer)*.025)
	return Vector3(cos(a)*r,sin(a*5.+v*2.+layer*.7)*.045+(layer-1.5)*.07,sin(a)*r)

static func reticulum_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Broad, pleated membrane sheets, stacked around an open central lumen.
	for layer in range(4):
		for i in range(64):
			for band in range(5):
				var corners:Array[Vector3]=[]
				var normals:Array[Vector3]=[]
				for uv:Vector2 in [Vector2(i,band),Vector2(i+1,band),Vector2(i,band+1),Vector2(i+1,band+1)]:
					var a:=uv.x*TAU/64.;var v:=uv.y/5.
					corners.append(sheet_point(a,v,layer))
					var along:=sheet_point(a+.001,v,layer)-sheet_point(a-.001,v,layer)
					var across:=sheet_point(a,v+.001,layer)-sheet_point(a,v-.001,layer)
					normals.append(along.cross(across).normalized())
				for face in [[0,2,1],[1,2,3]]:
					for side in [-1.,1.]:
						for index in (face if side>0 else [face[2],face[1],face[0]]):
							surface.set_color(Color.WHITE);surface.set_normal(normals[index]*side);surface.add_vertex(corners[index])
	return surface.commit()

func protein_collision(frame:Transform3D)->void:
	for j in range(56):
		var t:=TAU*j/56.;var r:=.29+.105*cos(t*3.)
		obstacles.add_box(frame*Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.09),Vector3(r*cos(2.*t),sin(3.*t)*.16,r*sin(2.*t))))

func emit(kind:String,mesh:Mesh,frame:Transform3D,color:Color,solid:bool=false)->void:
	var key:="%s:%d:%d"%[kind,floori(frame.origin.x/640.),floori(frame.origin.z/640.)]
	if not groups.has(key): groups[key]={"mesh":mesh,"items":[]}
	groups[key].items.append({"frame":frame,"color":color})
	if solid and obstacles: obstacles.add_box(frame,mesh.get_aabb())

func build(parent:Node3D,race:RefCounted)->void:
	var track:RefCounted=race.track
	obstacles=track.obstacles
	for i in range(track.nodes.size()):
		var a:Dictionary=track.nodes[i];var b:Dictionary=track.nodes[(i+1)%track.nodes.size()]
		var bounds:=AABB(a.p,Vector3.ZERO).expand(b.p).grow(maxf(a.width,b.width)+24.)
		if a.feature in ["jump","flight"]: bounds=bounds.grow(35.).expand(a.p+Vector3.UP*140.)
		for tile in Cells.cells(bounds):
			if not corridor.has(tile): corridor[tile]=[]
			corridor[tile].append(bounds)
	sphere=SphereMesh.new();sphere.radius=.5;sphere.height=1.;sphere.radial_segments=24;sphere.rings=12
	rod=CylinderMesh.new();rod.top_radius=.5;rod.bottom_radius=.5;rod.height=1.;rod.radial_segments=8
	tissue=ShaderMaterial.new();tissue.shader=load("res://src/cell_tissue.gdshader")
	var dna:=dna_mesh();var protein:=protein_mesh();var folds:=cristae_mesh();var reticulum:=reticulum_mesh()
	var rng:=RandomNumberGenerator.new();rng.seed=track.seed_value+92273
	# Dense, large structures along the course, with a generous flight corridor.
	for i in range(0,track.nodes.size(),9):
		var n:Dictionary=track.nodes[i]
		var side:=1. if rng.randf()>.5 else -1.
		var size:=rng.randf_range(110.,230.)
		var kind:="dna" if i%45==0 else ("protein" if rng.randf()<.5 else "mitochondrion")
		if kind=="dna": size=rng.randf_range(330.,590.)
		var center:Vector3=n.p+n.frame.x*side*rng.randf_range(125.,370.)+Vector3.UP*rng.randf_range(-100.,110.)
		var rotation:=Basis.from_euler(Vector3(rng.randf_range(-.45,.45),rng.randf()*TAU,rng.randf_range(-.35,.35)))
		var scale_vector:=Vector3.ONE*size
		if kind=="mitochondrion": scale_vector*=Vector3(.78,.55,1.35)
		var frame:=Transform3D(rotation.scaled_local(scale_vector),center)
		var mesh:Mesh=dna if kind=="dna" else (protein if kind=="protein" else sphere)
		var bounds:AABB=frame*mesh.get_aabb()
		if not clear(bounds.grow(8.)): continue
		specimens.append({"kind":kind,"frame":frame,"bounds":bounds.grow(8.)})
		var color:Color=[Color("d986a2"),Color("d99766"),Color("6cc5b4"),Color("ad8ad1")][rng.randi()%4]
		emit(kind,mesh,frame,Color.WHITE if kind=="dna" else color,kind=="mitochondrion")
		if kind=="mitochondrion": emit("cristae",folds,frame,Color("efb28c"))
		if kind=="dna":
			# Follow the actual backbones; the empty space between strands stays flyable.
			for strand in range(2):
				for j in range(72):
					var t0:=j/72.;var t1:=(j+1)/72.
					var a:=Vector3(cos(t0*TAU*3.+strand*PI)*.115,t0-.5,sin(t0*TAU*3.+strand*PI)*.115)
					var b:=Vector3(cos(t1*TAU*3.+strand*PI)*.115,t1-.5,sin(t1*TAU*3.+strand*PI)*.115)
					obstacles.add_box(frame*link(a,b,.032))
		elif kind=="protein":
			protein_collision(frame)
	# The nucleus anchors the centre of the scene, well inside the track's ring.
	var nucleus:=Transform3D(Basis.IDENTITY.scaled(Vector3(720.,630.,720.)),Vector3(0.,80.,0.))
	var nucleus_bounds:AABB=nucleus*sphere.get_aabb()
	if clear(nucleus_bounds.grow(15.)):
		specimens.append({"kind":"nucleus","frame":nucleus,"bounds":nucleus_bounds.grow(15.)})
		emit("nucleus",sphere,nucleus,Color("8d78ac"),true)
		for i in range(34):
			var y:=1.-2.*(i+.5)/34.;var a:=i*2.39996
			var normal:=Vector3(sqrt(1.-y*y)*cos(a),y,sqrt(1.-y*y)*sin(a))
			var point:Vector3=nucleus*(normal*.499)
			var pore:=TorusMesh.new();pore.inner_radius=10.;pore.outer_radius=16.;pore.rings=12;pore.ring_segments=8
			emit("nuclear_pore",pore,link(point,point+normal,1.),Color("eca6b2"))
	# Motor-protein inspired walkers carry vesicles on alternating articulated legs.
	for i in range(0,track.nodes.size(),24):
		var n:Dictionary=track.nodes[i]
		var size:=rng.randf_range(32.,52.)
		var center:Vector3=n.p+n.frame.x*(245. if i%48==0 else -245.)-Vector3.UP*25.
		var bounds:=AABB(center-Vector3(100.,16.,100.),Vector3(200.,size*2.6+16.,200.))
		if not clear(bounds): continue
		walkers.append({"center":center,"size":size,"phase":rng.randf()*TAU,"bounds":bounds})
		# A microtubule walkway, beneath each creature's entire pacing envelope.
		var start:=center-Vector3(0,8,66);var end:=center+Vector3(0,-8,66)
		emit("microtubule",rod,link(start,end,9.),Color("61afa8"),true)
		for bead in range(18):
			var p:=start.lerp(end,bead/17.)
			emit("tubulin",sphere,Transform3D(Basis.IDENTITY.scaled(Vector3(14.,11.,7.)),p),Color("77cbb8"))
	# A second layer of larger folded structures gives the cytoplasm depth on both sides.
	for i in range(42):
		var angle:=i*TAU/42.
		var center:=Vector3(cos(angle)*rng.randf_range(1500.,1950.),rng.randf_range(60.,600.),sin(angle)*rng.randf_range(1500.,1950.))
		var size:=rng.randf_range(240.,410.)
		var frame:=Transform3D(Basis.from_euler(Vector3(rng.randf()*TAU,rng.randf()*TAU,0.)).scaled_local(Vector3.ONE*size),center)
		var bounds:AABB=frame*reticulum.get_aabb()
		if not clear(bounds.grow(8.)): continue
		specimens.append({"kind":"reticulum","frame":frame,"bounds":bounds.grow(8.)})
		emit("reticulum",reticulum,frame,Color("ae789b") if i%2==0 else Color("639fbb"))
		# Narrow boxes follow the outer sheets instead of filling the central lumen.
		for ring in range(24):
			var a:=ring*TAU/24.
			obstacles.add_box(frame*Transform3D(Basis(Vector3.UP,-a).scaled_local(Vector3(.12,.28,.065)),Vector3(cos(a)*.3,0.,sin(a)*.3)))
	# Tiny distant vesicle clusters provide scale without screen-space speed streaks.
	for i in range(180):
		var center:=Vector3(rng.randf_range(-1800.,1800.),rng.randf_range(-180.,650.),rng.randf_range(-1800.,1800.))
		var size:=rng.randf_range(10.,34.)
		var frame:=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),center)
		var bounds:AABB=frame*sphere.get_aabb()
		if clear(bounds.grow(8.)):
			specimens.append({"kind":"vesicle","frame":frame,"bounds":bounds.grow(8.)})
			emit("vesicle",sphere,frame,Color("7cbaaf") if i%2==0 else Color("c9a483"),true)
	for key in groups:
		var group:Dictionary=groups[key]
		var data:=Batch.batch(parent,group.mesh,tissue,group.items.size())
		for i in range(group.items.size()):
			data.set_instance_transform(i,group.items[i].frame);data.set_instance_color(i,group.items[i].color)
	groups.clear()
	bodies=Batch.batch(parent,sphere,tissue,walkers.size()*2)
	legs=Batch.batch(parent,rod,tissue,walkers.size()*12)
	feet=Batch.batch(parent,sphere,tissue,walkers.size()*6)
	for i in range(bodies.instance_count): bodies.set_instance_color(i,Color("dc9dac") if i%2==0 else Color("88d6c0"))
	for i in range(legs.instance_count): legs.set_instance_color(i,Color("dbb679"))
	for i in range(feet.instance_count): feet.set_instance_color(i,Color("aee7c2"))
	# Opaque, inward-facing membrane: no costly transparent shell overdraw per view.
	membrane=ShaderMaterial.new();membrane.shader=load("res://src/cell_membrane.gdshader")
	var shell:=MeshInstance3D.new();shell.name="CellMembrane";shell.mesh=sphere;shell.material_override=membrane
	var lowest:=INF;var highest:=-INF;var reach:=0.
	for n in track.nodes: lowest=minf(lowest,n.p.y);highest=maxf(highest,n.p.y);reach=maxf(reach,Vector2(n.p.x,n.p.z).length())
	shell.position=Vector3(0.,(highest+lowest)*.5,0.)
	shell.scale=Vector3((reach+1200.)*2.,maxf(2800.,highest-lowest+2000.),(reach+1200.)*2.)
	shell.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(shell)
	for i in range(2):
		var probe:=ReflectionProbe.new();probe.position=track.nodes[track.nodes.size()*i/2].p+Vector3.UP*30.
		probe.size=Vector3(1300.,1100.,1300.);probe.max_distance=2200.;probe.blend_distance=200.
		probe.cull_mask=1;probe.reflection_mask=6;probe.intensity=.65;probe.update_mode=ReflectionProbe.UPDATE_ONCE
		parent.add_child(probe);probes.append(probe)
	animate(0.)

func animate(time:float)->void:
	animation_time=time
	if membrane: membrane.set_shader_parameter("race_time",time)
	if bodies==null: return
	obstacles.moving.clear()
	for i in range(walkers.size()):
		var w:Dictionary=walkers[i];var size:float=w.size;var phase:float=w.phase
		var base:Vector3=w.center+Vector3(0,0,sin(time*.18+phase)*38.)
		var gait:=time*2.5+phase
		var belly:=base+Vector3(0,size*.67+sin(gait*2.)*size*.035,0)
		var cargo:=belly+Vector3(0,size*.73,0)
		var body_frame:=Transform3D(Basis(Vector3.FORWARD,sin(gait)*.055).scaled_local(Vector3(size*.9,size*.7,size*1.25)),belly)
		var cargo_frame:=Transform3D(Basis.IDENTITY.scaled(Vector3(size*1.32,size*1.45,size*1.25)),cargo)
		bodies.set_instance_transform(i*2,body_frame);bodies.set_instance_transform(i*2+1,cargo_frame)
		obstacles.moving.append(body_frame);obstacles.moving.append(cargo_frame)
		for limb in range(6):
			var side:=1. if limb%2==0 else -1.;var row:=limb/2
			var cycle:=gait+(PI if limb%2==0 else 0.)+row*PI*.7
			var hip:=belly+Vector3(side*size*.22,-size*.06,(row-1)*size*.34)
			var foot:=base+Vector3(side*size*.68,maxf(0.,sin(cycle))*size*.22,(row-1)*size*.54+cos(cycle)*size*.25)
			var knee:Vector3=(hip+foot)*.5+Vector3(side*size*.26,size*.21,0)
			legs.set_instance_transform(i*12+limb*2,link(hip,knee,size*.095))
			legs.set_instance_transform(i*12+limb*2+1,link(knee,foot,size*.075))
			feet.set_instance_transform(i*6+limb,Transform3D(Basis.IDENTITY.scaled(Vector3(size*.19,size*.11,size*.28)),foot))
