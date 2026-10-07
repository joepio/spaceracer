extends "res://src/desert.gd"
## Seeded deep-sea reef: rounded reefs and trenches, kelp forests, glowing
## lantern weed, sea fans and sponges, and the creatures in OceanLife. Reuses
## the desert's swept-course clearance, boulders and natural arches.
const OceanTerrain=preload("res://src/ocean_terrain.gd")
const OceanLife=preload("res://src/ocean_life.gd")
const OCEAN_SUN:=Vector3(-66,-38,0)
const KELP:=0
const LANTERN:=1
const FAN:=2
const SPONGE:=3
var plants:Array[Dictionary]=[]
var animated:Array[ShaderMaterial]=[]
var life:RefCounted

func build(parent:Node3D,race:RefCounted)->void:
	index_course(race)
	terrain=OceanTerrain.new(track)
	ground=terrain.build(parent,Basis.from_euler(OCEAN_SUN*PI/180.).z)
	animated.append(ground)
	if track.obstacles: track.obstacles.terrain=terrain
	rock_material=ShaderMaterial.new();rock_material.shader=load("res://src/ocean_rock.gdshader")
	animated.append(rock_material)
	scatter_reef(parent)
	build_arches(parent)
	life=OceanLife.new()
	life.build(parent,race,self)
	add_probes(parent)
	animate(0.)

static func sweep(surface:SurfaceTool,path:PackedVector3Array,radius:Callable,color:Color,sides:int=8,inside:bool=false)->void:
	# A tube along `path`; UV.x runs around it and UV.y along it.
	var count:=path.size()
	for i in range(count-1):
		var t0:=i/float(count-1);var t1:=(i+1)/float(count-1)
		var f0:=(path[mini(i+1,count-1)]-path[maxi(i-1,0)]).normalized()
		var f1:=(path[mini(i+2,count-1)]-path[i]).normalized()
		var x0:=f0.cross(Vector3.RIGHT if absf(f0.x)<.9 else Vector3.FORWARD).normalized();var y0:=f0.cross(x0)
		var x1:=f1.cross(Vector3.RIGHT if absf(f1.x)<.9 else Vector3.FORWARD).normalized();var y1:=f1.cross(x1)
		var r0:float=radius.call(t0);var r1:float=radius.call(t1)
		for side in range(sides):
			var a0:=side*TAU/sides;var a1:=(side+1)*TAU/sides
			var corners:=[[path[i],x0*cos(a0)+y0*sin(a0),r0,side,t0],[path[i+1],x1*cos(a0)+y1*sin(a0),r1,side,t1],[path[i],x0*cos(a1)+y0*sin(a1),r0,side+1,t0],
				[path[i],x0*cos(a1)+y0*sin(a1),r0,side+1,t0],[path[i+1],x1*cos(a0)+y1*sin(a0),r1,side,t1],[path[i+1],x1*cos(a1)+y1*sin(a1),r1,side+1,t1]]
			if inside: corners=[corners[0],corners[2],corners[1],corners[3],corners[5],corners[4]]
			for c in corners:
				surface.set_color(color);surface.set_uv(Vector2(float(c[3])/sides,c[4]))
				surface.set_normal(-c[1] if inside else c[1])
				surface.add_vertex(c[0]+c[1]*c[2])

static func blade(surface:SurfaceTool,root:Vector3,out:Vector3,length:float,width:float,lift:float,droop:float,base:Color,tip:Color)->void:
	# A long, gently drooping leaf: a ribbon of quads from root to tip.
	var across:=out.cross(Vector3.UP).normalized()
	const SEGMENTS:=6
	var points:Array[Vector3]=[]
	for i in range(SEGMENTS+1):
		var s:=i/float(SEGMENTS)
		points.append(root+out*length*s+Vector3.UP*length*(lift*s-droop*s*s))
	for i in range(SEGMENTS):
		var s0:=i/float(SEGMENTS);var s1:=(i+1)/float(SEGMENTS)
		var w0:=width*sin(PI*minf(s0*.92+.08,1.));var w1:=width*sin(PI*minf(s1*.92+.08,1.))
		var a:=points[i]-across*w0;var b:=points[i]+across*w0
		var c:=points[i+1]-across*w1;var d:=points[i+1]+across*w1
		var normal:=(c-a).cross(b-a).normalized()
		if normal.y<0.: normal=-normal
		for v in [[a,0.,s0],[c,0.,s1],[b,1.,s0],[b,1.,s0],[c,0.,s1],[d,1.,s1]]:
			surface.set_color(base.lerp(tip,v[2]));surface.set_normal(normal);surface.set_uv(Vector2(v[1],v[2]))
			surface.add_vertex(v[0])

static func kelp_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalk:=PackedVector3Array()
	for i in range(17):
		var t:=i/16.
		stalk.append(Vector3(sin(t*3.)*.012,t,cos(t*2.3)*.008))
	sweep(surface,stalk,func(t:float)->float:return lerpf(.007,.003,t),Color(.42,.3,.1),5)
	for i in range(23):
		var h:=.07+i*.04
		var angle:=i*2.4
		var out:=Vector3(cos(angle),0.,sin(angle))
		var length:=lerpf(.13,.07,h)
		blade(surface,Vector3(sin(h*3.)*.012,h,cos(h*2.3)*.008),out,length*1.3,.03,.9,.5,Color(.4,.3,.08),Color(.66,.56,.18))
	return surface.commit()

static func lantern_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A crozier stem that rises and curls over, ending in a hanging glow bulb.
	var stem:=PackedVector3Array()
	var p:=Vector3.ZERO
	stem.append(p)
	for i in range(1,25):
		var t:=i/24.
		var theta:=t*t*2.5
		p+=Vector3(sin(theta),cos(theta),0.)*(1.15/24.)
		stem.append(p)
	sweep(surface,stem,func(t:float)->float:return lerpf(.024,.009,t),Color(.2,.14,.27,0.),7)
	var tip:=stem[stem.size()-1]
	var direction:=(stem[stem.size()-1]-stem[stem.size()-2]).normalized()
	bulb(surface,tip+direction*.09,.1,Color(1.,1.,1.,1.))
	for t in [.42,.6,.76]:
		var at:=stem[roundi(t*24.)]
		bulb(surface,at+Vector3(0.,-.02,.04),.03,Color(1.,1.,1.,1.))
	for i in range(6):
		var angle:=i*TAU/6.+.3
		blade(surface,Vector3(0.,.02,0.),Vector3(cos(angle),0.,sin(angle)),.22,.05,.6,.7,Color(.16,.1,.24,0.),Color(.3,.2,.4,0.))
	return surface.commit()

static func lantern_tip()->Vector3:
	# Where lantern_mesh hangs its big bulb, in mesh space.
	var p:=Vector3.ZERO
	var previous:=p
	for i in range(1,25):
		var theta:=pow(i/24.,2.)*2.5
		previous=p
		p+=Vector3(sin(theta),cos(theta),0.)*(1.15/24.)
	return p+(p-previous).normalized()*.09

static func bulb(surface:SurfaceTool,center:Vector3,radius:float,color:Color)->void:
	var sphere:=SphereMesh.new();sphere.radius=radius;sphere.height=radius*2.3;sphere.radial_segments=12;sphere.rings=8
	var arrays:=sphere.get_mesh_arrays()
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	for index in arrays[Mesh.ARRAY_INDEX]:
		surface.set_color(color);surface.set_normal(normals[index]);surface.set_uv(uvs[index])
		surface.add_vertex(center+vertices[index])

static func fan_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const GRID:=8
	for z in range(GRID):
		for x in range(GRID):
			var quad:=[]
			for corner in [[x,z],[x,z+1],[x+1,z],[x+1,z],[x,z+1],[x+1,z+1]]:
				var u:float=corner[0]/float(GRID);var v:float=corner[1]/float(GRID)
				# Slightly cupped, like a fan leaning into the current.
				quad.append([Vector3(u-.5,v,-.08*pow(absf(u-.5)*2.,2.)),Vector2(u,v)])
			for c in quad:
				surface.set_color(Color.WHITE);surface.set_normal(Vector3.BACK);surface.set_uv(c[1]);surface.add_vertex(c[0])
	var trunk:=PackedVector3Array([Vector3(0.,-.12,0.),Vector3(0.,-.04,0.),Vector3(0.,.06,0.)])
	var start:=surface.commit_to_arrays()
	var tube:=SurfaceTool.new();tube.begin(Mesh.PRIMITIVE_TRIANGLES)
	sweep(tube,trunk,func(t:float)->float:return .022,Color(.8,.8,.8),6)
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,start)
	var trunk_arrays:=tube.commit_to_arrays()
	var uvs:PackedVector2Array=trunk_arrays[Mesh.ARRAY_TEX_UV]
	for i in range(uvs.size()): uvs[i].y=-.1
	trunk_arrays[Mesh.ARRAY_TEX_UV]=uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,trunk_arrays)
	return mesh

static func sponge_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng:=RandomNumberGenerator.new();rng.seed=9917
	var palette:=[Color(.62,.24,.55),Color(.85,.45,.16),Color(.86,.72,.3),Color(.3,.5,.72),Color(.78,.32,.3)]
	for k in range(8):
		var angle:=k*2.4
		var spot:=Vector3(cos(angle),0.,sin(angle))*(.08+.32*sqrt(k/8.))
		var height:=rng.randf_range(.35,1.)*(1.-k*.05)
		var radius:=rng.randf_range(.06,.12)
		var tint:Color=palette[rng.randi_range(0,palette.size()-1)]
		var lean:=Vector3(spot.x,0.,spot.z)*.25
		var path:=PackedVector3Array()
		for i in range(7): path.append(spot+lean*(i/6.)*height+Vector3.UP*height*i/6.)
		var flare:=func(t:float)->float:return radius*(1.+.35*t*t)
		sweep(surface,path,flare,Color(tint.r,tint.g,tint.b,0.),9)
		var inner:=func(t:float)->float:return radius*(1.+.35*t*t)*.8
		var top:=PackedVector3Array([path[4],path[5],path[6]])
		sweep(surface,top,inner,Color(tint.r*.25,tint.g*.2,tint.b*.25,0.),9,true)
		# A glowing lip around each mouth.
		var lip:=PackedVector3Array([path[6]-Vector3.UP*.004,path[6]+Vector3.UP*.012])
		sweep(surface,lip,func(t:float)->float:return radius*1.36,Color(1.,1.,1.,1.),9)
	return surface.commit()

func scatter_reef(parent:Node3D)->void:
	var rng:=RandomNumberGenerator.new();rng.seed=track.seed_value+71713
	var meshes:Array[Mesh]=[rock_mesh(0),rock_mesh(1),rock_mesh(2),rock_mesh(3)]
	var plant_meshes:Array[Mesh]=[kelp_mesh(),lantern_mesh(),fan_mesh(),sponge_mesh()]
	var rock_groups:Dictionary={}
	var plant_groups:Dictionary={}
	for x in range(-24,25):
		for z in range(-24,25):
			var center:=Vector3(x*130.+rng.randf_range(-60.,60.),0.,z*130.+rng.randf_range(-60.,60.))
			if center.length()>3300.: continue
			center.y=terrain.height_at(center.x,center.z)
			var normal:Vector3=terrain.normal_at(center.x,center.z)
			var roll:=rng.randf()
			if roll<.2:
				var variant:=rng.randi_range(2,3) if rng.randf()<.8 else rng.randi_range(0,1)
				var size:=rng.randf_range(8.,30.) if variant>=2 else rng.randf_range(30.,80.)
				var transform:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).rotated(Vector3.RIGHT,rng.randf_range(-.25,.25)).scaled(Vector3(size*rng.randf_range(.9,1.6),size*(1. if variant>=2 else 1.),size*rng.randf_range(.8,1.3))),center-Vector3.UP*(2. if variant>=2 else 4.))
				var bounds:AABB=transform*meshes[variant].get_aabb()
				if not clear(bounds.grow(4.)): continue
				rocks.append({"transform":transform,"variant":variant,"bounds":bounds})
				if track.obstacles:
					var core:AABB=meshes[variant].get_aabb()
					track.obstacles.add_box(transform,AABB(core.position*.75,core.size*.75))
				var key:=Vector3i(floori(center.x/900.),variant,floori(center.z/900.))
				if not rock_groups.has(key): rock_groups[key]=[]
				var shade:=rng.randf_range(.85,1.08)
				rock_groups[key].append({"transform":transform,"color":Color(shade,shade,shade)})
				continue
			var kind:=-1;var members:=1;var spread:=0.
			if roll<.5 and normal.y>.8: kind=KELP;members=rng.randi_range(4,8);spread=55.
			elif roll<.6 and normal.y>.75: kind=LANTERN;members=rng.randi_range(1,4);spread=40.
			elif roll<.7: kind=FAN;members=rng.randi_range(1,3);spread=35.
			elif roll<.8 and normal.y>.7: kind=SPONGE;members=rng.randi_range(1,2);spread=25.
			if kind<0: continue
			for k in range(members):
				var spot:=center+Vector3(rng.randf_range(-spread,spread),0.,rng.randf_range(-spread,spread))
				spot.y=terrain.height_at(spot.x,spot.z)-.5
				var size:float
				var yaw:=rng.randf()*TAU
				var color:=Color.WHITE
				match kind:
					KELP:
						size=rng.randf_range(40.,115.)
						var shade:=rng.randf_range(.8,1.15);color=Color(shade,shade*rng.randf_range(.92,1.05),shade*.9)
					LANTERN:
						size=rng.randf_range(40.,85.)
						color=[Color(.35,1.,.9),Color(.95,.45,1.),Color(.55,.75,1.),Color(1.,.75,.4)][rng.randi_range(0,3)]
					FAN:
						size=rng.randf_range(18.,42.)
						color=[Color(.85,.22,.25),Color(.62,.25,.7),Color(.95,.55,.2),Color(.95,.85,.4)][rng.randi_range(0,3)]
					_:
						size=rng.randf_range(10.,24.)
				var transform:=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*size),spot)
				var local:AABB=plant_meshes[kind].get_aabb()
				var bounds:AABB=(transform*local).grow(2. if kind!=KELP else 8.)
				if kind==KELP: bounds=bounds.grow(size*.05)
				if not clear(bounds): continue
				plants.append({"transform":transform,"kind":kind,"bounds":bounds})
				if track.obstacles:
					var stalk:=AABB(Vector3(-.02,0.,-.02),Vector3(.04,.8,.04))
					if kind==FAN: stalk=AABB(Vector3(-.4,0.,-.05),Vector3(.8,.85,.1))
					elif kind==SPONGE: stalk=AABB(Vector3(-.35,0.,-.35),Vector3(.7,.7,.7))
					track.obstacles.add_box(transform,stalk)
				var key:=Vector3i(floori(spot.x/900.),kind,floori(spot.z/900.))
				if not plant_groups.has(key): plant_groups[key]=[]
				plant_groups[key].append({"transform":transform,"color":color})
	for key in rock_groups:
		var records:Array=rock_groups[key]
		var data:=Batch.batch(parent,meshes[key.y],rock_material,records.size())
		for i in range(records.size()):
			data.set_instance_transform(i,records[i].transform);data.set_instance_color(i,records[i].color)
	var plant_materials:Array[ShaderMaterial]=[]
	for kind in range(4):
		var material:=ShaderMaterial.new();material.shader=load("res://src/ocean_plant.gdshader")
		material.set_shader_parameter("kind",kind)
		material.set_shader_parameter("glow_color",Vector3(.35,1.,.85))
		plant_materials.append(material);animated.append(material)
	var halos:Array[Dictionary]=[]
	for key in plant_groups:
		var records:Array=plant_groups[key]
		var data:=Batch.batch(parent,plant_meshes[key.y],plant_materials[key.y],records.size())
		for i in range(records.size()):
			data.set_instance_transform(i,records[i].transform);data.set_instance_color(i,records[i].color)
			if key.y==LANTERN: halos.append(records[i])
	# Soft halos make the lantern bulbs glow through the water on every renderer.
	var halo_material:=ShaderMaterial.new();halo_material.shader=load("res://src/ocean_drift.gdshader")
	halo_material.set_shader_parameter("kind",3);animated.append(halo_material)
	var quad:=QuadMesh.new();quad.size=Vector2.ONE
	var glow:=Batch.batch(parent,quad,halo_material,halos.size(),1,true,false)
	var tip:=lantern_tip()
	for i in range(halos.size()):
		var transform:Transform3D=halos[i].transform
		var size:float=transform.basis.get_scale().y
		glow.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size*.75),transform*tip))
		glow.set_instance_color(i,halos[i].color)

func animate(time:float)->void:
	animation_time=time
	for material in animated: material.set_shader_parameter("race_time",time)
	if life: life.animate(time)
