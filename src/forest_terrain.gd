extends RefCounted
## One seeded height field shared by the landscape mesh, planting and collisions.
const STEP:=24.
const CELLS:=320
const HALF:=STEP*CELLS*.5
const CHUNK:=16
var heights:=PackedFloat32Array()
var water_level:float
var minimum:=INF
var maximum:=-INF

func _init(track:RefCounted)->void:
	water_level=track.water_level
	var hills:=FastNoiseLite.new()
	hills.seed=track.seed_value+49187;hills.frequency=.00135
	hills.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hills.fractal_octaves=3;hills.fractal_gain=.38
	heights.resize((CELLS+1)*(CELLS+1))
	for z in range(CELLS+1):
		for x in range(CELLS+1):
			var p:=Vector2(x*STEP-HALF,z*STEP-HALF)
			# Broad connected hills with submerged valleys, not a mound per tree.
			var h:=water_level+18.+hills.get_noise_2d(p.x,p.y)*145.
			var edge:=smoothstep(HALF-650.,HALF,maxf(absf(p.x),absf(p.y)))
			heights[z*(CELLS+1)+x]=lerpf(h,water_level-55.,edge)
	# Carve smooth clearances below the complete road cross-section. Include a
	# full grid-cell margin so interpolated triangles cannot cut across the road.
	for i in range(track.nodes.size()):
		var a:Dictionary=track.nodes[i]
		var b:Dictionary=track.nodes[(i+1)%track.nodes.size()]
		var start:=Vector2(a.p.x,a.p.z)
		var end:=Vector2(b.p.x,b.p.z)
		var delta:=end-start
		var width:float=maxf(a.width,b.width)
		var inner:=width+STEP*1.5
		if a.feature in ["jump","flight"]: inner+=45.
		var outer:=inner+120.
		var ceiling:float=minf(a.p.y,b.p.y)-width-16.
		var lo:=Vector2i((start.min(end)-Vector2.ONE*outer+Vector2.ONE*HALF)/STEP)
		var hi:=Vector2i((start.max(end)+Vector2.ONE*outer+Vector2.ONE*HALF)/STEP)+Vector2i.ONE
		for z in range(maxi(0,lo.y),mini(CELLS,hi.y)+1):
			for x in range(maxi(0,lo.x),mini(CELLS,hi.x)+1):
				var p:=Vector2(x*STEP-HALF,z*STEP-HALF)
				var t:=clampf((p-start).dot(delta)/maxf(delta.length_squared(),.001),0.,1.)
				var distance:=p.distance_to(start+delta*t)
				if distance>=outer: continue
				var id:=z*(CELLS+1)+x
				var h:=heights[id]
				# A ceiling envelope avoids accumulating depressions as node density changes.
				var cap:=ceiling+smoothstep(inner,outer,distance)*180.
				heights[id]=minf(h,cap)
	for h in heights: minimum=minf(minimum,h);maximum=maxf(maximum,h)

func height_at(x:float,z:float)->float:
	var grid:=Vector2((x+HALF)/STEP,(z+HALF)/STEP)
	if grid.x<0. or grid.y<0. or grid.x>=CELLS or grid.y>=CELLS: return water_level-55.
	var ix:=floori(grid.x);var iz:=floori(grid.y)
	var u:=grid.x-ix;var v:=grid.y-iz
	var id:=iz*(CELLS+1)+ix
	var a:=heights[id];var b:=heights[id+1]
	var c:=heights[id+CELLS+1];var d:=heights[id+CELLS+2]
	# Match the rendered triangle diagonal exactly, including ridge collisions.
	return a+(b-a)*u+(c-a)*v if u+v<=1. else d+(c-d)*(1.-u)+(b-d)*(1.-v)

func normal_at(x:float,z:float)->Vector3:
	return Vector3(height_at(x-2.,z)-height_at(x+2.,z),4.,height_at(x,z-2.)-height_at(x,z+2.)).normalized()

func build(parent:Node3D)->void:
	var material:=ShaderMaterial.new()
	material.shader=load("res://src/forest_ground.gdshader")
	material.set_shader_parameter("water_level",water_level)
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
			instance.name="Landscape_%d_%d"%[cx,cz]
			parent.add_child(instance)

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
