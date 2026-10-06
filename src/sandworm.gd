extends RefCounted
## A giant sandworm that bursts out of the dunes beside the course, arcs high
## over the road and dives back into the sand on the far side. Purely visual:
## it never collides, so it can only distract. Driven by the pausable race clock.
const SEGMENTS:=46
const SPACING:=6.4
const RADIUS:=12.
const SPEED:=82.
const DUST:=240
const DUST_LIFE:=3.6
const COOLDOWN:=6.
const AMBIENT:=38.
var sites:Array[Dictionary]=[]
var race:RefCounted
var track:RefCounted
var body:MultiMesh
var body_node:MultiMeshInstance3D
var head:MeshInstance3D
var dust:MultiMesh
var dust_node:MultiMeshInstance3D
var active:=-1
var last_time:=0.
var eruptions:=0

static func ring_radius(z:float)->float:
	# Each armoured plate flares toward the head and tucks into the next joint.
	return .80+.20*smoothstep(-.5,.3,z)-.2*smoothstep(.3,.5,z)

static func segment_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES:=20
	const ROWS:=8
	for row in range(ROWS):
		var z0:=-.5+row/float(ROWS);var z1:=-.5+(row+1)/float(ROWS)
		for side in range(SIDES):
			var a0:=side*TAU/SIDES;var a1:=(side+1)*TAU/SIDES
			for corner in [[z0,a0],[z1,a0],[z0,a1],[z0,a1],[z1,a0],[z1,a1]]:
				var z:float=corner[0];var angle:float=corner[1]
				var r:=ring_radius(z)
				var slope:=(ring_radius(z+.01)-ring_radius(z-.01))/.02
				var normal:=Vector3(cos(angle),sin(angle),-slope).normalized()
				# Dusty plates above, paler belly, dark creases in each joint.
				var crease:=smoothstep(.3,.5,absf(z))
				var belly:=smoothstep(.2,-.9,sin(angle))
				var tint:=Color(.45,.35,.27).lerp(Color(.76,.66,.52),belly).lerp(Color(.16,.11,.09),crease*.85)
				surface.set_color(tint);surface.set_normal(normal)
				surface.add_vertex(Vector3(cos(angle)*r,sin(angle)*r,z))
	# A crest of worn, bony spines along the back of every plate.
	for k in range(5):
		var angle:=PI*.5+(k-2)*.32
		var base:=Vector3(cos(angle)*.98,sin(angle)*.98,.22)
		tooth(surface,base,(Vector3(cos(angle),sin(angle),0.)+Vector3(0,0,-.35)).normalized(),.07,.22-absf(k-2)*.04,Color(.78,.7,.56))
	return surface.commit()

static func head_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const PETALS:=3
	const ACROSS:=10
	const ALONG:=9
	# Three armoured jaws peel open like a flower; the inside is wet, dark flesh.
	for petal in range(PETALS):
		var start:=petal*TAU/PETALS+.06
		var span:=TAU/PETALS-.12
		for side in [1.,-1.]:
			for i in range(ALONG):
				for j in range(ACROSS):
					var quad:=[]
					for corner in [[i,j],[i+1,j],[i,j+1],[i,j+1],[i+1,j],[i+1,j+1]]:
						quad.append(jaw_point(start,span,corner[0]/float(ALONG),corner[1]/float(ACROSS)))
					if side<0.: quad=[quad[0],quad[2],quad[1],quad[3],quad[5],quad[4]]
					for k in range(6):
						var p:Vector3=quad[k]
						var t:float=clampf((p.z-.45)/1.3,0.,1.)
						var normal:Vector3=Vector3(p.x,p.y,-.35).normalized()*side
						var outer:=Color(.56,.46,.36).lerp(Color(.42,.33,.26),t)
						var inner:=Color(.42,.07,.06).lerp(Color(.9,.42,.34),t)
						var color:=outer if side>0. else inner
						color.a=1. if side>0. else 0.
						surface.set_color(color);surface.set_normal(normal);surface.add_vertex(p)
		# Rows of crystalline teeth line each jaw, pointing back into the throat.
		for row in range(3):
			for k in range(7):
				var along:=.25+row*.25
				var across:=(k+.5)/7.
				var base:=jaw_point(start,span,along,across)
				var axis:=Vector3(0,0,base.z-.35)
				var inward:=(axis-base).normalized()
				tooth(surface,base,(inward+Vector3(0,0,-.6)).normalized(),.07-row*.012,.32-row*.06)
	# The throat: a dark cone that swallows the light.
	const SIDES:=18
	for side in range(SIDES):
		var a0:=side*TAU/SIDES;var a1:=(side+1)*TAU/SIDES
		for p in [Vector3(cos(a0)*1.,sin(a0)*1.,.5),Vector3(0,0,-.6),Vector3(cos(a1)*1.,sin(a1)*1.,.5)]:
			surface.set_color(Color(.08,.01,.01,0.));surface.set_normal(Vector3(0,0,1));surface.add_vertex(p)
	# A short neck plate so the head joins the first body ring seamlessly.
	for row in range(4):
		var z0:=-.5+row*.25;var z1:=z0+.25
		for side in range(SIDES):
			var a0:=side*TAU/SIDES;var a1:=(side+1)*TAU/SIDES
			for corner in [[z0,a0],[z1,a0],[z0,a1],[z0,a1],[z1,a0],[z1,a1]]:
				var r:float=1.02+.06*(corner[0]+.5)
				surface.set_color(Color(.55,.45,.35));surface.set_normal(Vector3(cos(corner[1]),sin(corner[1]),0))
				surface.add_vertex(Vector3(cos(corner[1])*r,sin(corner[1])*r,corner[0]))
	return surface.commit()

static func jaw_point(start:float,span:float,along:float,across:float)->Vector3:
	var angle:=start+span*across
	# Open outward, then curl the tips back in like grasping fingers.
	var flare:=1.04+along*1.45-pow(along,3.)*.6
	var edge:=sin(across*PI)
	var radius:=flare*(1.-.04*edge)
	var z:=.5+along*1.6-(1.-edge)*along*.3
	return Vector3(cos(angle)*radius,sin(angle)*radius,z)

static func tooth(surface:SurfaceTool,base:Vector3,direction:Vector3,radius:float,length:float,color:Color=Color(.93,.88,.76,0.))->void:
	var x:=direction.cross(Vector3.UP if absf(direction.y)<.9 else Vector3.RIGHT).normalized()
	var y:=direction.cross(x)
	var tip:=base+direction*length
	for side in range(5):
		var a0:=side*TAU/5.;var a1:=(side+1)*TAU/5.
		var p0:=base+(x*cos(a0)+y*sin(a0))*radius
		var p1:=base+(x*cos(a1)+y*sin(a1))*radius
		var normal:=(p1-p0).cross(tip-p0).normalized()
		for p in [p0,tip,p1]:
			surface.set_color(color);surface.set_normal(normal);surface.add_vertex(p)

func build(parent:Node3D,state:RefCounted,desert:RefCounted)->void:
	race=state
	track=state.track
	var worm_material:=ShaderMaterial.new();worm_material.shader=load("res://src/desert_worm.gdshader")
	body=MultiMesh.new();body.transform_format=MultiMesh.TRANSFORM_3D
	body.mesh=segment_mesh();body.instance_count=SEGMENTS
	body_node=MultiMeshInstance3D.new();body_node.name="SandwormBody";body_node.multimesh=body
	body_node.material_override=worm_material
	# Huge, fast-moving geometry: keep it out of static GI, still cast shadows.
	body_node.set_meta("gi_dynamic",true)
	body_node.custom_aabb=AABB(Vector3.ONE*-6000.,Vector3.ONE*12000.)
	parent.add_child(body_node)
	head=MeshInstance3D.new();head.name="SandwormHead";head.mesh=head_mesh()
	head.material_override=worm_material;head.set_meta("gi_dynamic",true)
	parent.add_child(head)
	var dust_material:=ShaderMaterial.new();dust_material.shader=load("res://src/desert_dust.gdshader")
	dust=MultiMesh.new();dust.transform_format=MultiMesh.TRANSFORM_3D;dust.use_colors=true
	var quad:=QuadMesh.new();quad.size=Vector2.ONE;dust.mesh=quad;dust.instance_count=DUST
	dust_node=MultiMeshInstance3D.new();dust_node.name="SandwormDust";dust_node.multimesh=dust
	dust_node.material_override=dust_material;dust_node.set_meta("gi_dynamic",true)
	dust_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust_node.custom_aabb=AABB(Vector3.ONE*-6000.,Vector3.ONE*12000.)
	parent.add_child(dust_node)
	choose_sites(desert)
	hide()

func choose_sites(desert:RefCounted)->void:
	# Open dune stretches where the worm can rise on one side and dive on the
	# other, spread around the lap so every pilot meets it.
	var count:int=track.nodes.size()
	var candidates:Array[Dictionary]=[]
	for index in range(count):
		var basin_gap:=INF
		for center in desert.terrain.basins:
			basin_gap=minf(basin_gap,absf(fposmod(index*track.step-center+track.length*.5,track.length)-track.length*.5))
		if basin_gap>desert.terrain.BASIN: continue
		var n:Dictionary=track.nodes[index]
		if not desert.eligible(n): continue
		if not track.jump_at(index*track.step,500.).is_empty(): continue
		var near_arch:=false
		for arch in desert.arches:
			if arch.origin.distance_to(n.p)<260.: near_arch=true
		if near_arch: continue
		var site:=site_path(n,desert)
		if site.is_empty(): continue
		site.distance=index*track.step
		site.start=-INF
		candidates.append(site)
	for basin in desert.terrain.basins:
		var target:float=basin/track.length
		var best:Dictionary={}
		var best_gap:=INF
		for site in candidates:
			var spaced:=true
			for chosen in sites:
				var apart:=absf(fposmod(site.distance-chosen.distance+track.length*.5,track.length)-track.length*.5)
				if apart<track.length*.18: spaced=false
			if not spaced: continue
			var gap:=absf(fposmod(site.distance-target*track.length+track.length*.5,track.length)-track.length*.5)
			if gap<best_gap and gap<desert.terrain.BASIN: best_gap=gap;best=site
		if not best.is_empty(): sites.append(best)

func site_path(n:Dictionary,desert:RefCounted)->Dictionary:
	var across:Vector3=-n.frame.x;across.y=0.;across=across.normalized()
	var along:=across.cross(Vector3.UP).normalized()
	var reach:float=n.width+105.
	var a:Vector3=n.p-across*reach;var b:Vector3=n.p+across*reach
	var ground_a:float=desert.terrain.height_at(a.x,a.z)
	var ground_b:float=desert.terrain.height_at(b.x,b.z)
	var peak:float=n.p.y+95.
	if peak-maxf(ground_a,ground_b)<70.: return {}
	var points:=PackedVector3Array()
	var lengths:=PackedFloat32Array()
	var total:=0.
	var surface_a:=-1.;var surface_b:=-1.
	for i in range(161):
		var x:=lerpf(-1.25,1.25,i/160.)
		var ground:=ground_a if x<0. else ground_b
		# A flat crown high over the road, near-vertical where it breaks the sand.
		var y:=peak-(peak-ground)*x*x*x*x
		var p:Vector3=n.p+across*x*reach+along*sin(x*PI*.5)*30.
		p.y=y
		if i>0: total+=p.distance_to(points[-1])
		points.append(p);lengths.append(total)
		var above:bool=y>desert.terrain.height_at(p.x,p.z)
		if above and surface_a<0.: surface_a=total
		if not above and surface_a>=0. and surface_b<0.: surface_b=total
		# Only open sky between the two holes: no rock walls, no other decks.
		if absf(x)<.93:
			if y-RADIUS*1.6<desert.terrain.height_at(p.x,p.z): return {}
			if not desert.course_clear(p,RADIUS*1.4,58.): return {}
	if surface_a<0. or surface_b<0.: return {}
	return {"points":points,"lengths":lengths,"total":total,"surface_a":surface_a,"surface_b":surface_b,"lead":maxf(0.,surface_a-30.),
		"hole_a":Vector3(a.x,ground_a,a.z),"hole_b":Vector3(b.x,ground_b,b.z),"across":across}

static func at(site:Dictionary,s:float)->Transform3D:
	var lengths:PackedFloat32Array=site.lengths
	var points:PackedVector3Array=site.points
	s=clampf(s,0.,site.total)
	var i:=clampi(lengths.bsearch(s)-1,0,points.size()-2)
	var f:=(s-lengths[i])/maxf(lengths[i+1]-lengths[i],.001)
	var p:=points[i].lerp(points[i+1],f)
	var forward:=(points[i+1]-points[i]).normalized()
	var x:=Vector3.UP.cross(forward).normalized()
	return Transform3D(Basis(x,forward.cross(x),forward),p)

func duration(site:Dictionary)->float:
	return (site.total-site.lead+SEGMENTS*SPACING)/SPEED

func hide()->void:
	body_node.visible=false;head.visible=false;dust_node.visible=false

func trigger(time:float)->void:
	for i in range(sites.size()):
		var site:Dictionary=sites[i]
		if time-site.start<duration(site)+DUST_LIFE+COOLDOWN: return
	# Erupt ahead of the leading pilot so it arcs overhead as the pack arrives.
	for p in race.racers:
		if p.get("crashed",false) or p.get("finished",false): continue
		for i in range(sites.size()):
			var ahead:=fposmod(sites[i].distance-p.distance,track.length)
			if ahead>230. and ahead<480.:
				sites[i].start=time;active=i;eruptions+=1
				return
	# With no pilot nearby, the desert still stirs now and then.
	var idle:=INF
	for site in sites: idle=minf(idle,time-site.start)
	if idle>AMBIENT and not sites.is_empty():
		var i:=posmod(eruptions,sites.size())
		sites[i].start=time;active=i;eruptions+=1

func animate(time:float)->void:
	if sites.is_empty(): return
	if time<last_time-.5:
		for site in sites: site.start=-INF
		active=-1
	last_time=time
	trigger(time)
	if active<0: hide();return
	var site:Dictionary=sites[active]
	var age:float=time-site.start
	if age<0. or age>duration(site)+DUST_LIFE: hide();return
	var head_s:float=site.lead+age*SPEED
	var moving:bool=head_s<site.total+SEGMENTS*SPACING
	body_node.visible=moving;head.visible=moving
	if moving:
		var head_frame:=at(site,head_s)
		head.transform=Transform3D(head_frame.basis.scaled_local(Vector3.ONE*RADIUS*1.08),head_frame.origin)
		for k in range(SEGMENTS):
			var t:=k/float(SEGMENTS-1)
			var frame:=at(site,head_s-(k+.5)*SPACING)
			# A slow peristaltic swell runs down the body; the tail tapers away.
			var radius:=RADIUS*(1.-.55*pow(t,1.6))*(1.+.05*sin(t*18.-time*6.))
			body.set_instance_transform(k,Transform3D(frame.basis.scaled_local(Vector3(radius,radius,SPACING*1.12)),frame.origin))
	dust_node.visible=true
	var rng:=RandomNumberGenerator.new()
	for i in range(DUST):
		rng.seed=i*7919+active*104729+1
		# Each hole sprays while the body passes through it, heaviest at the burst.
		var exit:=i%2==1
		var hole:Vector3=site.hole_b if exit else site.hole_a
		var opened:float=((site.surface_b if exit else site.surface_a)-site.lead)/SPEED-.15
		var spray:=SEGMENTS*SPACING/SPEED
		var born:=opened+pow(rng.randf(),2.2)*spray
		var kind:=rng.randf()
		var heavy:=kind<.3
		var wave:=kind>.78
		var life:=DUST_LIFE*(.55 if heavy else rng.randf_range(.75,1.))
		var a:=age-born
		if a<0. or a>life:
			dust.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.001),hole))
			dust.set_instance_color(i,Color(1,1,1,0))
			continue
		var angle:=rng.randf()*TAU
		var outward:=Vector3(cos(angle),0.,sin(angle))
		var launch:=outward*rng.randf_range(4.,26.)+Vector3.UP*rng.randf_range(22.,64.)*(1.4 if heavy else 1.)
		# A low, rolling ring of sand races outward from the breach.
		if wave: launch=outward*rng.randf_range(35.,70.)+Vector3.UP*rng.randf_range(2.,7.)
		var drag:=.3 if heavy else (1.3 if wave else 1.1)
		var gravity:=34. if heavy else (2. if wave else 6.)
		var travel:=launch*(1.-exp(-drag*a))/drag+Vector3.DOWN*.5*gravity*a*a
		var position:=hole+outward*rng.randf_range(RADIUS*.3,RADIUS*1.6)+travel
		var size:=rng.randf_range(3.,6.) if heavy else (rng.randf_range(16.,28.)+a*(16. if wave else 22.))
		var fade:=pow(1.-a/life,1.3)*minf(a*8.,1.)
		dust.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),position))
		dust.set_instance_color(i,Color(1.,1.,1.,fade*(.95 if heavy else .85)))
