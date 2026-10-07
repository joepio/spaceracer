extends RefCounted
## The reef's inhabitants: fish schools, drifting jellyfish, gliding manta rays
## and giant octopuses, plus marine snow, bubble vents and light shafts. All
## purely visual and driven by the pausable race clock; only the octopus bodies
## collide, and every creature keeps its distance from the racing line.
const Batch=preload("res://src/scenery.gd")
const SCHOOLS:=12
const FISH_PER_SCHOOL:=60
const SWARMS:=7
const JELLIES_PER_SWARM:=16
const MANTAS:=6
const SNOW:=1600
const VENTS:=16
const BUBBLES_PER_VENT:=30
const SHAFTS:=40
const OCTOPUS_ARMS:=8
var track:RefCounted
var scenery:RefCounted
var schools:Array[Dictionary]=[]
var fish:MultiMesh
var fish_offsets:=PackedVector3Array()
var fish_positions:=PackedVector3Array()
var jellies:Array[Dictionary]=[]
var jelly_data:MultiMesh
var mantas:Array[Dictionary]=[]
var manta_data:MultiMesh
var octopuses:Array[Dictionary]=[]
var arms:MultiMesh
var materials:Array[ShaderMaterial]=[]
var animation_time:=-1.

static func material(path:String,kind:int=-1)->ShaderMaterial:
	var result:=ShaderMaterial.new();result.shader=load(path)
	if kind>=0: result.set_shader_parameter("kind",kind)
	return result

func beside(rng:RandomNumberGenerator,fraction:float,near:float,far:float)->Dictionary:
	var n:Dictionary=track.sample(track.length*fposmod(fraction,1.))
	var side:Vector3=-n.frame.x;side.y=0.;side=side.normalized()
	if rng.randf()<.5: side=-side
	var point:Vector3=n.p+side*rng.randf_range(near,far)
	return {"node":n,"side":side,"point":point,"floor":scenery.terrain.height_at(point.x,point.z)}

func build(parent:Node3D,race:RefCounted,owner:RefCounted)->void:
	track=race.track
	scenery=owner
	var rng:=RandomNumberGenerator.new();rng.seed=track.seed_value+81919
	build_fish(parent,rng)
	build_jellies(parent,rng)
	build_mantas(parent,rng)
	build_octopuses(parent,rng)
	build_drift(parent,rng)
	# Drop the back reference: the scenery owns this object, not the reverse.
	scenery=null
	animate(0.)

# --- Fish ---------------------------------------------------------------

static func fish_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const RINGS:=8
	const SIDES:=8
	var rows:Array[PackedVector3Array]=[]
	for ring in range(RINGS+1):
		var z:=lerpf(-.5,.32,ring/float(RINGS))
		var t:=(z+.5)/.82
		var girth:=sin(PI*clampf(t*.95+.05,0.,1.))*(1.-t*.55)
		var row:=PackedVector3Array()
		for side in range(SIDES):
			var a:=side*TAU/SIDES
			row.append(Vector3(cos(a)*.075*girth,sin(a)*.17*girth,z))
		rows.append(row)
	for ring in range(RINGS):
		for side in range(SIDES):
			var a:=rows[ring][side];var b:=rows[ring][(side+1)%SIDES]
			var c:=rows[ring+1][side];var d:=rows[ring+1][(side+1)%SIDES]
			for v in [a,c,b,b,c,d]:
				surface.set_color(Color(.2,.36,.5).lerp(Color(.9,.94,.96),smoothstep(.06,-.1,v.y)))
				surface.add_vertex(v)
	# Forked tail and a sail-like dorsal fin.
	var tail:=[Vector3(0.,0.,.3),Vector3(0.,.2,.56),Vector3(0.,.02,.46),Vector3(0.,0.,.3),Vector3(0.,.02,.46),Vector3(0.,-.18,.55)]
	var dorsal:=[Vector3(0.,.15,-.18),Vector3(0.,.3,.0),Vector3(0.,.12,.12)]
	for v in tail+dorsal:
		surface.set_color(Color(.32,.46,.6));surface.add_vertex(v)
	surface.generate_normals()
	return surface.commit()

func build_fish(parent:Node3D,rng:RandomNumberGenerator)->void:
	var tints:=[Color(1.3,1.3,1.3),Color(1.6,1.3,.3),Color(1.7,.7,.3),Color(.8,1.2,1.6),Color(1.4,.8,1.4)]
	for i in range(SCHOOLS):
		var spot:=beside(rng,(i+rng.randf_range(.1,.9))/SCHOOLS,45.,130.)
		var home:Vector3=spot.point
		home.y=maxf(float(spot.floor)+18.,float(spot.node.p.y)+rng.randf_range(-5.,45.))
		schools.append({"home":home,"radius":Vector2(rng.randf_range(40.,100.),rng.randf_range(30.,80.)),
			"speed":rng.randf_range(.1,.18)*(1. if rng.randf()<.5 else -1.),"phase":rng.randf()*TAU,
			"size":rng.randf_range(3.,6.),"tint":tints[rng.randi_range(0,tints.size()-1)]})
	for i in range(SCHOOLS*FISH_PER_SCHOOL):
		var size:float=schools[i/FISH_PER_SCHOOL].size
		fish_offsets.append(Vector3(rng.randf_range(-1.,1.)*9.,rng.randf_range(-1.,1.)*4.,rng.randf_range(-1.,1.)*14.)*size*.45)
	fish_positions.resize(fish_offsets.size())
	var shader:=material("res://src/ocean_creature.gdshader",0);materials.append(shader)
	fish=Batch.batch(parent,fish_mesh(),shader,SCHOOLS*FISH_PER_SCHOOL,1,true,false)
	for i in range(fish.instance_count):
		var school:Dictionary=schools[i/FISH_PER_SCHOOL]
		var shade:=rng.randf_range(.85,1.1)
		fish.set_instance_color(i,Color(school.tint.r*shade,school.tint.g*shade,school.tint.b*shade))

static func orbit(home:Vector3,radius:Vector2,angle:float,bob:float)->Vector3:
	return home+Vector3(cos(angle)*radius.x,sin(angle*2.)*bob,sin(angle)*radius.y)

func animate_fish(time:float)->void:
	for s in range(SCHOOLS):
		var school:Dictionary=schools[s]
		var angle:float=school.phase+time*school.speed
		var center:=orbit(school.home,school.radius,angle,6.)
		var ahead:=orbit(school.home,school.radius,angle+.05*signf(school.speed),6.)
		var basis:=Basis.looking_at((ahead-center).normalized(),Vector3.UP)
		for k in range(FISH_PER_SCHOOL):
			var i:=s*FISH_PER_SCHOOL+k
			var offset:=fish_offsets[i]
			var wobble:=Vector3(sin(time*1.3+k),sin(time*.9+k*1.7)*.5,cos(time*1.1+k*.7))*1.2
			var turn:=Basis(Vector3.UP,sin(time*.8+k)*.12)
			fish_positions[i]=center+basis*offset+wobble
			fish.set_instance_transform(i,Transform3D((basis*turn).scaled(Vector3.ONE*school.size),fish_positions[i]))

# --- Jellyfish ----------------------------------------------------------

static func jelly_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES:=20
	const ROWS:=7
	for row in range(ROWS):
		for side in range(SIDES):
			var quad:=[]
			for corner in [[row,side],[row+1,side],[row,side+1],[row,side+1],[row+1,side],[row+1,side+1]]:
				var t:float=corner[0]/float(ROWS)
				var a:float=corner[1]*TAU/SIDES
				# A soft dome with a slightly flared, scalloped margin.
				var polar:=t*PI*.55
				var r:=sin(polar)*.5*(1.+.06*sin(a*8.)*t)
				var y:=cos(polar)*.42-.1*t*t
				var normal:=Vector3(sin(polar)*cos(a),cos(polar),sin(polar)*sin(a))
				quad.append([Vector3(cos(a)*r,y,sin(a)*r),normal,t])
			for c in quad:
				surface.set_color(Color.WHITE);surface.set_normal(c[1]);surface.set_uv(Vector2(0.,c[2]));surface.add_vertex(c[0])
	# Long trailing tentacles and four frilled oral arms, as crossed ribbons.
	for k in range(14):
		var a:=k*TAU/14.
		var root:=Vector3(cos(a)*.44,.0,sin(a)*.44)
		ribbon(surface,root,2.6,.012)
	for k in range(4):
		var a:=k*TAU/4.+.4
		ribbon(surface,Vector3(cos(a)*.06,.05,sin(a)*.06),1.4,.06)
	return surface.commit()

static func ribbon(surface:SurfaceTool,root:Vector3,length:float,width:float)->void:
	const SEGMENTS:=10
	for across in [Vector3.RIGHT,Vector3.BACK]:
		for i in range(SEGMENTS):
			var s0:=i/float(SEGMENTS);var s1:=(i+1)/float(SEGMENTS)
			var p0:=root+Vector3.DOWN*length*s0;var p1:=root+Vector3.DOWN*length*s1
			var w0:=width*(1.-s0*.7);var w1:=width*(1.-s1*.7)
			for v in [[p0-across*w0,s0],[p1-across*w1,s1],[p0+across*w0,s0],[p0+across*w0,s0],[p1-across*w1,s1],[p1+across*w1,s1]]:
				surface.set_color(Color.WHITE);surface.set_normal(across.cross(Vector3.DOWN));surface.set_uv(Vector2(1.,v[1]));surface.add_vertex(v[0])

func build_jellies(parent:Node3D,rng:RandomNumberGenerator)->void:
	var tints:=[Color(1.,.45,.85),Color(.45,.85,1.),Color(.7,.5,1.),Color(1.,.7,.4),Color(.5,1.,.8)]
	for s in range(SWARMS):
		var spot:=beside(rng,(s+rng.randf_range(.1,.9))/SWARMS,45.,190.)
		var tint:Color=tints[rng.randi_range(0,tints.size()-1)]
		for k in range(JELLIES_PER_SWARM):
			var size:=rng.randf_range(3.,12.) if rng.randf()<.85 else rng.randf_range(16.,26.)
			var point:Vector3=spot.point+Vector3(rng.randf_range(-70.,70.),0.,rng.randf_range(-70.,70.))
			var floor_height:float=scenery.terrain.height_at(point.x,point.z)
			point.y=maxf(floor_height+size*3.+4.,float(spot.node.p.y)+rng.randf_range(-10.,80.))
			# Jellies drift but never hang across the road or its flight envelope.
			if not scenery.course_clear(point+Vector3.DOWN*size,size*2.6+14.,size+20.): continue
			jellies.append({"home":point,"size":size,"phase":rng.randf()*TAU,"tint":tint.lerp(Color.WHITE,rng.randf_range(0.,.3))})
	var shader:=material("res://src/ocean_jelly.gdshader");materials.append(shader)
	jelly_data=Batch.batch(parent,jelly_mesh(),shader,jellies.size(),1,true,false)
	for i in range(jellies.size()): jelly_data.set_instance_color(i,jellies[i].tint)

func animate_jellies(time:float)->void:
	for i in range(jellies.size()):
		var jelly:Dictionary=jellies[i]
		var p:Vector3=jelly.home+Vector3(sin(time*.05+jelly.phase)*6.,sin(time*.12+jelly.phase)*5.,cos(time*.04+jelly.phase*1.3)*6.)
		var basis:=Basis(Vector3.UP,time*.05+jelly.phase).rotated(Vector3.RIGHT,sin(time*.2+jelly.phase)*.1)
		jelly_data.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*float(jelly.size)),p))

# --- Manta rays ---------------------------------------------------------

static func manta_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SPAN:=24
	const CHORD:=6
	for face in [1.,-1.]:
		for ix in range(SPAN):
			for iz in range(CHORD):
				var quad:=[]
				for corner in [[ix,iz],[ix,iz+1],[ix+1,iz],[ix+1,iz],[ix,iz+1],[ix+1,iz+1]]:
					var x:=lerpf(-1.,1.,corner[0]/float(SPAN))
					var span:=absf(x)
					var lead:=-.5+.56*pow(span,1.25)
					var trail:=.4-.34*pow(span,.75)
					var z:=lerpf(lead,trail,corner[1]/float(CHORD))
					var thick:=.07*pow(1.-span,2.)*sin(PI*corner[1]/float(CHORD))+.004
					quad.append(Vector3(x,thick*face,z))
				if face<0.: quad=[quad[0],quad[2],quad[1],quad[3],quad[5],quad[4]]
				for v in quad:
					var shoulder:=smoothstep(.25,.0,Vector2(absf(v.x)-.3,v.z+.12).length())
					var top:=Color(.06,.08,.1).lerp(Color(.75,.78,.8),shoulder*.6)
					surface.set_color(top if face>0. else Color(.86,.88,.9));surface.add_vertex(v)
	# Cephalic horns and a whip tail.
	for side in [-1.,1.]:
		for v in [Vector3(.08*side,0.,-.45),Vector3(.16*side,0.,-.62),Vector3(.15*side,0.,-.42)]:
			surface.set_color(Color(.08,.1,.12));surface.add_vertex(v)
	for v in [Vector3(-.02,0.,.38),Vector3(0.,0.,1.5),Vector3(.02,0.,.38)]:
		surface.set_color(Color(.08,.1,.12));surface.add_vertex(v)
	surface.generate_normals()
	return surface.commit()

func build_mantas(parent:Node3D,rng:RandomNumberGenerator)->void:
	for i in range(MANTAS):
		var spot:=beside(rng,(i+rng.randf_range(.1,.9))/MANTAS,110.,230.)
		var home:Vector3=spot.point
		home.y=maxf(float(spot.floor)+40.,float(spot.node.p.y)+rng.randf_range(40.,110.))
		mantas.append({"home":home,"radius":rng.randf_range(60.,110.),"speed":rng.randf_range(.07,.11)*(1. if rng.randf()<.5 else -1.),
			"phase":rng.randf()*TAU,"size":rng.randf_range(11.,19.)})
	var shader:=material("res://src/ocean_creature.gdshader",1);materials.append(shader)
	manta_data=Batch.batch(parent,manta_mesh(),shader,MANTAS,1,true)
	for i in range(MANTAS): manta_data.set_instance_color(i,Color.WHITE)

func animate_mantas(time:float)->void:
	for i in range(mantas.size()):
		var manta:Dictionary=mantas[i]
		var angle:float=manta.phase+time*manta.speed
		var radius:=Vector2(manta.radius,manta.radius*.8)
		var p:=orbit(manta.home,radius,angle,10.)
		var ahead:=orbit(manta.home,radius,angle+.04*signf(manta.speed),10.)
		var basis:=Basis.looking_at((ahead-p).normalized(),Vector3.UP)
		# Bank into the turn like a glider.
		basis=basis*Basis(Vector3.BACK,-.35*signf(manta.speed))
		manta_data.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*float(manta.size)),p))

# --- Octopuses ----------------------------------------------------------

static func mantle_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere:=SphereMesh.new();sphere.radius=1.;sphere.height=2.;sphere.radial_segments=28;sphere.rings=18
	var arrays:=sphere.get_mesh_arrays()
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	# The bulbous mantle leans back over a broad, webbed base.
	var lean:=Basis(Vector3.RIGHT,.5)
	for index in arrays[Mesh.ARRAY_INDEX]:
		var v:=vertices[index]
		var head:=lean*Vector3(v.x*.85,v.y*1.3,v.z*.95)+Vector3(0.,1.45,.35)
		surface.set_color(Color(1.,1.,1.,0.));surface.set_uv(uvs[index]);surface.add_vertex(head)
	for index in arrays[Mesh.ARRAY_INDEX]:
		var v:=vertices[index]
		surface.set_color(Color(1.,1.,1.,0.));surface.set_uv(uvs[index]);surface.add_vertex(Vector3(v.x*1.15,v.y*.42+.35,v.z*1.15))
	var eye:=SphereMesh.new();eye.radius=.2;eye.height=.4;eye.radial_segments=16;eye.rings=10
	var eye_arrays:=eye.get_mesh_arrays()
	var eye_vertices:PackedVector3Array=eye_arrays[Mesh.ARRAY_VERTEX]
	var eye_uvs:PackedVector2Array=eye_arrays[Mesh.ARRAY_TEX_UV]
	for side in [-1.,1.]:
		for index in eye_arrays[Mesh.ARRAY_INDEX]:
			surface.set_color(Color(1.,1.,1.,1.));surface.set_uv(eye_uvs[index])
			surface.add_vertex(eye_vertices[index]+Vector3(.58*side,.95,-.5))
	surface.generate_normals()
	return surface.commit()

static func arm_mesh()->ArrayMesh:
	# Only the topology matters: the shader bends every ring along the arm.
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const RINGS:=48
	const SIDES:=10
	for ring in range(RINGS):
		for side in range(SIDES):
			for corner in [[ring,side],[ring,side+1],[ring+1,side],[ring,side+1],[ring+1,side+1],[ring+1,side]]:
				surface.set_color(Color.WHITE);surface.set_uv(Vector2(corner[1]/float(SIDES),corner[0]/float(RINGS)))
				surface.set_normal(Vector3.UP);surface.add_vertex(Vector3(0.,corner[0]/float(RINGS),0.))
	var mesh:=surface.commit()
	mesh.custom_aabb=AABB(Vector3(-1.2,-1.2,-1.2),Vector3(2.4,2.4,2.4))
	return mesh

func octopus_sites(rng:RandomNumberGenerator)->Array[Dictionary]:
	# Open sand plains near the course: the same basins the desert keeps for its worm.
	var anchors:Array[float]=[]
	for center in scenery.terrain.basins: anchors.append(center/track.length)
	for fraction in [.12,.45,.78]:
		if anchors.size()>=4: break
		anchors.append(fraction)
	var result:Array[Dictionary]=[]
	for fraction in anchors:
		if result.size()>=4: break
		for attempt in range(10):
			var spot:=beside(rng,fraction+rng.randf_range(-.02,.02),220.,300.)
			var size:=rng.randf_range(22.,28.)
			var arm:=size*5.
			var n:Dictionary=spot.node
			var point:Vector3=spot.point
			point.y=spot.floor
			if Vector2(point.x-n.p.x,point.z-n.p.z).length()<arm+n.width+30.: continue
			if scenery.terrain.normal_at(point.x,point.z).y<.82: continue
			if not scenery.course_clear(point+Vector3.UP*size*1.4,arm+size,size*3.): continue
			var crowded:=false
			for other in result:
				if other.position.distance_to(point)<600.: crowded=true
			if crowded: continue
			result.append({"position":point,"size":size,"arm":arm,"facing":(Vector3(n.p.x,point.y,n.p.z)-point).normalized(),"phase":rng.randf()*TAU})
			break
	return result

func build_octopuses(parent:Node3D,rng:RandomNumberGenerator)->void:
	octopuses=octopus_sites(rng)
	var body_material:=material("res://src/ocean_creature.gdshader",2);materials.append(body_material)
	var arm_material:=material("res://src/ocean_creature.gdshader",3);materials.append(arm_material)
	var body:=mantle_mesh()
	arms=MultiMesh.new()
	arms.transform_format=MultiMesh.TRANSFORM_3D
	arms.use_colors=true;arms.use_custom_data=true
	arms.mesh=arm_mesh()
	arms.instance_count=octopuses.size()*OCTOPUS_ARMS
	var renderer:=MultiMeshInstance3D.new();renderer.multimesh=arms;renderer.material_override=arm_material
	renderer.set_meta("gi_dynamic",true)
	parent.add_child(renderer)
	for o in range(octopuses.size()):
		var octopus:Dictionary=octopuses[o]
		var size:float=octopus.size
		var basis:=Basis.looking_at(octopus.facing,Vector3.UP)
		var instance:=MeshInstance3D.new();instance.name="GiantOctopus";instance.mesh=body;instance.material_override=body_material
		instance.transform=Transform3D(basis.scaled(Vector3.ONE*size),octopus.position-Vector3.UP*size*.15)
		instance.set_meta("gi_dynamic",true)
		parent.add_child(instance)
		octopus.node=instance
		if track.obstacles: track.obstacles.add_box(instance.transform,AABB(Vector3(-1.1,0.,-1.1),Vector3(2.2,2.6,2.2)))
		# Two front arms rise toward the course; the rest sprawl and curl.
		for k in range(OCTOPUS_ARMS):
			var angle:=(k+.5)*TAU/OCTOPUS_ARMS
			var out:=basis*Vector3(sin(angle),0.,-cos(angle))
			var raised:=k==0 or k==OCTOPUS_ARMS-1
			var length:float=octopus.arm*rng.randf_range(.85,1.1)
			var root:Vector3=octopus.position+out*size*.8+Vector3.UP*size*.3
			var arm_basis:=Basis(out,Vector3.UP,out.cross(Vector3.UP)).scaled(Vector3.ONE*length)
			var index:=o*OCTOPUS_ARMS+k
			arms.set_instance_transform(index,Transform3D(arm_basis,root))
			arms.set_instance_color(index,Color.WHITE)
			var base:=rng.randf_range(.25,.5) if raised else rng.randf_range(1.35,1.5)
			var curl:=base+(rng.randf_range(1.2,1.9) if raised else rng.randf_range(1.4,2.8))
			arms.set_instance_custom_data(index,Color(rng.randf()*TAU,base,curl,rng.randf_range(.35,.5) if raised else rng.randf_range(.15,.3)))

# --- Snow, bubbles and light --------------------------------------------

func build_drift(parent:Node3D,rng:RandomNumberGenerator)->void:
	var quad:=QuadMesh.new();quad.size=Vector2.ONE
	var everywhere:=QuadMesh.new();everywhere.size=Vector2.ONE
	everywhere.custom_aabb=AABB(Vector3.ONE*-100000.,Vector3.ONE*200000.)
	var snow_material:=material("res://src/ocean_drift.gdshader",0);materials.append(snow_material)
	var snow:=Batch.batch(parent,everywhere,snow_material,SNOW,1,true,false)
	for i in range(SNOW):
		snow.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*rng.randf_range(.15,.45)),Vector3(rng.randf(),rng.randf(),rng.randf())*160.))
		snow.set_instance_color(i,Color.WHITE)
	var tall:=QuadMesh.new();tall.size=Vector2.ONE
	tall.custom_aabb=AABB(Vector3(-2.,-1.,-2.),Vector3(4.,250.,4.))
	var bubble_material:=material("res://src/ocean_drift.gdshader",1);materials.append(bubble_material)
	var bubbles:=Batch.batch(parent,tall,bubble_material,VENTS*BUBBLES_PER_VENT,1,true,false)
	for v in range(VENTS):
		var spot:=beside(rng,(v+rng.randf())/VENTS,35.,200.)
		var base:Vector3=spot.point;base.y=spot.floor
		var height:=rng.randf_range(70.,160.)
		var speed:=rng.randf_range(4.,8.)
		for k in range(BUBBLES_PER_VENT):
			var i:=v*BUBBLES_PER_VENT+k
			bubbles.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*rng.randf_range(.5,1.4)),base+Vector3(rng.randf_range(-2.,2.),0.,rng.randf_range(-2.,2.))))
			bubbles.set_instance_color(i,Color(height/200.,speed/10.,0.))
	var shaft_mesh:=QuadMesh.new();shaft_mesh.size=Vector2.ONE
	shaft_mesh.custom_aabb=AABB(Vector3(-1.,-1.,-1.),Vector3(2.,2.,2.))
	var shaft_material:=material("res://src/ocean_drift.gdshader",2);materials.append(shaft_material)
	var shafts:=Batch.batch(parent,shaft_mesh,shaft_material,SHAFTS,1,true,false)
	for i in range(SHAFTS):
		var spot:=beside(rng,rng.randf(),0.,260.)
		var base:Vector3=spot.point;base.y=spot.floor
		var width:=rng.randf_range(16.,48.)
		shafts.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(width,rng.randf_range(260.,420.),width)),base))
		shafts.set_instance_color(i,Color.WHITE)

func animate(time:float)->void:
	if time==animation_time: return
	animation_time=time
	for shader in materials: shader.set_shader_parameter("race_time",time)
	animate_fish(time)
	animate_jellies(time)
	animate_mantas(time)
