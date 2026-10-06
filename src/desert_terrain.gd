extends RefCounted
## Seeded dune sea with sandstone ranges. The course is carved through canyons:
## one height field is shared by the landscape mesh, props and collisions.
const STEP:=24.
const CELLS:=320
const HALF:=STEP*CELLS*.5
const CHUNK:=16
const REACH:=430.
var heights:=PackedFloat32Array()
var floor_level:float
var minimum:=INF
var maximum:=-INF
var basins:Array[float]=[]
const BASIN:=320.

## Open dune basins spread around the lap: the sandworm's hunting grounds.
static func worm_basins(track:RefCounted)->Array[float]:
	var result:Array[float]=[]
	var count:int=track.nodes.size()
	for target in [.22,.55,.85]:
		for offset in range(0,count/5):
			var found:=false
			for direction in [1,-1]:
				var index:=posmod(roundi(target*count)+offset*direction,count)
				var n:Dictionary=track.nodes[index]
				if not n.feature in ["ribbon","open"] or n.loop or n.canyon or n.split_gap>.01 or absf(n.slope)>.2: continue
				if not track.jump_at(index*track.step,500.).is_empty(): continue
				result.append(index*track.step);found=true;break
			if found: break
	return result

static func terrace(h:float,base:float,band:float)->float:
	# Flat-topped strata steps give mesas and buttes their layered silhouette.
	var t:=(h-base)/band
	return base+(floorf(t)+smoothstep(.62,1.,t-floorf(t)))*band

func _init(track:RefCounted)->void:
	basins=worm_basins(track)
	var lowest:=INF
	for n in track.nodes: lowest=minf(lowest,n.p.y)
	floor_level=lowest-48.
	var dunes:=FastNoiseLite.new()
	dunes.seed=track.seed_value+30211;dunes.frequency=.0042
	dunes.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;dunes.fractal_octaves=2
	var swell:=FastNoiseLite.new()
	swell.seed=track.seed_value+30212;swell.frequency=.0011
	swell.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;swell.fractal_octaves=3
	var ranges:=FastNoiseLite.new()
	ranges.seed=track.seed_value+30213;ranges.frequency=.0012
	ranges.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;ranges.fractal_octaves=3;ranges.fractal_gain=.42
	var skyline:=FastNoiseLite.new()
	skyline.seed=track.seed_value+30215;skyline.frequency=.0016
	skyline.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH;skyline.fractal_octaves=2
	var mask:=FastNoiseLite.new()
	mask.seed=track.seed_value+30214;mask.frequency=.00055
	heights.resize((CELLS+1)*(CELLS+1))
	for z in range(CELLS+1):
		for x in range(CELLS+1):
			var p:=Vector2(x*STEP-HALF,z*STEP-HALF)
			# Long, wind-aligned dune crests on a broad sandy swell.
			var warped:=p+Vector2(dunes.get_noise_2d(p.y*.4,p.x*.4)*180.,0.)
			var crest:=1.-absf(dunes.get_noise_2d(warped.x*.55,warped.y*1.6))
			var h:=floor_level+6.+swell.get_noise_2d(p.x,p.y)*38.+crest*crest*crest*34.
			# Flat-topped mesas: stepped plateaus with sheer cliffs between them.
			var range_mask:=smoothstep(-.15,.3,mask.get_noise_2d(p.x,p.y))
			var m:=ranges.get_noise_2d(p.x,p.y)*range_mask
			h+=smoothstep(.10,.16,m)*110.+smoothstep(.27,.32,m)*95.+smoothstep(.42,.46,m)*80.
			# A broken ring of great mesas and buttes frames every horizon.
			var radial:=p.length()
			var far:=skyline.get_noise_2d(p.x,p.y)
			h+=smoothstep(2200.,3300.,radial)*(70.+smoothstep(-.25,-.17,far)*190.+smoothstep(.12,.19,far)*170.+smoothstep(.4,.45,far)*120.)
			var edge:=smoothstep(HALF-500.,HALF,maxf(absf(p.x),absf(p.y)))
			heights[z*(CELLS+1)+x]=lerpf(h,floor_level+220.,edge)
	# Nearest course distance, lowest nearby road and the canyon character.
	var count:=(CELLS+1)*(CELLS+1)
	var nearest:=PackedFloat32Array();nearest.resize(count);nearest.fill(INF)
	var low:=PackedFloat32Array();low.resize(count);low.fill(INF)
	var cap:=PackedFloat32Array();cap.resize(count);cap.fill(INF)
	var slot:=PackedFloat32Array();slot.resize(count)
	var walls:=PackedFloat32Array();walls.resize(count)
	var open:=PackedFloat32Array();open.resize(count)
	var base:=PackedFloat32Array();base.resize(count)
	var wall_distance:=PackedFloat32Array();wall_distance.resize(count);wall_distance.fill(INF)
	var nodes:Array=track.nodes
	for i in range(0,nodes.size(),2):
		var a:Dictionary=nodes[i]
		var b:Dictionary=nodes[(i+2)%nodes.size()]
		var start:=Vector2(a.p.x,a.p.z)
		var end:=Vector2(b.p.x,b.p.z)
		var delta:=end-start
		var width:float=maxf(a.width,b.width)
		var inner:=width+STEP*1.5
		if a.feature in ["jump","flight"] or b.feature in ["jump","flight"]: inner+=45.
		var ceiling:float=minf(a.p.y,b.p.y)-width-16.
		# Canyon stretches alternate with open dune sea along the lap.
		var u:float=a.u
		var character:=smoothstep(.08,.42,sin(u*TAU*3.+track.phase)*.5+.5+sin(u*TAU*7.+1.3)*.18)
		# Loops and jumps carve clearance but never anchor a canyon wall.
		var anchors:bool=not (a.loop or b.loop or a.feature in ["jump","flight"] or b.feature in ["jump","flight"])
		var gorge:=1. if a.get("canyon",false) else 0.
		var basin:=0.
		for center in basins:
			var apart:=absf(fposmod(i*track.step-center+track.length*.5,track.length)-track.length*.5)
			basin=maxf(basin,1.-smoothstep(BASIN*.6,BASIN,apart))
		character*=1.-basin;gorge*=1.-basin
		var lo:=Vector2i((start.min(end)-Vector2.ONE*REACH+Vector2.ONE*HALF)/STEP)
		var hi:=Vector2i((start.max(end)+Vector2.ONE*REACH+Vector2.ONE*HALF)/STEP)+Vector2i.ONE
		for z in range(maxi(0,lo.y),mini(CELLS,hi.y)+1):
			for x in range(maxi(0,lo.x),mini(CELLS,hi.x)+1):
				var p:=Vector2(x*STEP-HALF,z*STEP-HALF)
				var t:=clampf((p-start).dot(delta)/maxf(delta.length_squared(),.001),0.,1.)
				var distance:=p.distance_to(start+delta*t)
				if distance>=REACH: continue
				var id:=z*(CELLS+1)+x
				low[id]=minf(low[id],ceiling)
				# Same envelope as the forest: the road cross-section is always clear.
				cap[id]=minf(cap[id],ceiling+smoothstep(inner,inner+65.,distance)*900.)
				nearest[id]=minf(nearest[id],distance)
				if distance<REACH*.8: open[id]=maxf(open[id],basin*(1.-smoothstep(REACH*.5,REACH*.8,distance)))
				if anchors and distance<wall_distance[id]:
					wall_distance[id]=distance
					walls[id]=character
					slot[id]=gorge
					base[id]=ceiling
	for id in range(count):
		if nearest[id]>=REACH: continue
		var d:=nearest[id]
		var h:=heights[id]
		var anchor:float=base[id] if wall_distance[id]<REACH else low[id]
		var inner:=60.
		# Canyon walls: sheer near the course, easing back into the dune sea.
		var strength:=maxf(walls[id],slot[id])
		var rise:=smoothstep(inner,inner+(55. if slot[id]>.5 else 110.),d)*(1.-smoothstep(260.,REACH,d))
		var wall:=anchor+40.+(175.+slot[id]*120.)*strength
		wall=terrace(wall,floor_level,46.)
		h=maxf(h,lerpf(h,wall,rise))
		# Basins stay low, rolling sand so the worm has room to breach.
		h=lerpf(h,minf(h,low[id]+18.+(h-floor_level)*.15),open[id])
		# A dry wash floor in the canyon bottom.
		h=minf(h,cap[id])
		heights[id]=h
	for h in heights: minimum=minf(minimum,h);maximum=maxf(maximum,h)

func height_at(x:float,z:float)->float:
	var grid:=Vector2((x+HALF)/STEP,(z+HALF)/STEP)
	if grid.x<0. or grid.y<0. or grid.x>=CELLS or grid.y>=CELLS: return floor_level
	var ix:=floori(grid.x);var iz:=floori(grid.y)
	var u:=grid.x-ix;var v:=grid.y-iz
	var id:=iz*(CELLS+1)+ix
	var a:=heights[id];var b:=heights[id+1]
	var c:=heights[id+CELLS+1];var d:=heights[id+CELLS+2]
	# Match the rendered triangle diagonal exactly, including ridge collisions.
	return a+(b-a)*u+(c-a)*v if u+v<=1. else d+(c-d)*(1.-u)+(b-d)*(1.-v)

func normal_at(x:float,z:float)->Vector3:
	return Vector3(height_at(x-2.,z)-height_at(x+2.,z),4.,height_at(x,z-2.)-height_at(x,z+2.)).normalized()

func build(parent:Node3D,sun_direction:Vector3)->ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=load("res://src/desert_ground.gdshader")
	material.set_shader_parameter("floor_level",floor_level)
	material.set_shader_parameter("sun_direction",sun_direction)
	for cz in range(0,CELLS,CHUNK):
		for cx in range(0,CELLS,CHUNK):
			var vertices:=PackedVector3Array()
			var normals:=PackedVector3Array()
			var indices:=PackedInt32Array()
			for z in range(CHUNK+1):
				for x in range(CHUNK+1):
					var wx:float=(cx+x)*STEP-HALF;var wz:float=(cz+z)*STEP-HALF
					vertices.append(Vector3(wx,heights[(cz+z)*(CELLS+1)+cx+x],wz))
					normals.append(normal_at(wx,wz))
			for z in range(CHUNK):
				for x in range(CHUNK):
					var a:=z*(CHUNK+1)+x;var b:=a+1;var c:=a+CHUNK+1;var d:=c+1
					indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
			var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.material_override=material
			instance.name="Dunes_%d_%d"%[cx,cz]
			parent.add_child(instance)
	return material

func trace(from:Vector3,to:Vector3,radius:float)->Dictionary:
	if minf(from.y,to.y)>maximum+radius: return {}
	var steps:=maxi(1,ceili(from.distance_to(to)/(STEP*.25)))
	var previous:=0.
	for i in range(steps+1):
		var t:=i/float(steps)
		var p:=from.lerp(to,t)
		if p.y-radius<=height_at(p.x,p.z):
			var low:=previous;var high:=t
			for iteration in range(8):
				var mid:=(low+high)*.5
				var point:=from.lerp(to,mid)
				if point.y-radius>height_at(point.x,point.z): low=mid
				else: high=mid
			p=from.lerp(to,high)
			p.y=height_at(p.x,p.z)+radius
			return {"position":p,"normal":normal_at(p.x,p.z)}
		previous=t
	return {}
