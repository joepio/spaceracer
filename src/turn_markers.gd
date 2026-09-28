extends RefCounted
## Animated severity chevrons and broken-rail pictograms in three shared draws.
const Track=preload("res://src/track.gd")

static func quad(surface:SurfaceTool,frame:Transform3D,a:Vector3,b:Vector3,c:Vector3,d:Vector3)->void:
	var normal:Vector3=frame.basis*(-(b-a).cross(c-a).normalized())
	var points:=[a,b,c,a,c,d]
	var uvs:=[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]
	for i in range(6):
		surface.set_normal(normal)
		surface.set_uv(uvs[i])
		surface.add_vertex(frame*points[i])

static func stroke(surface:SurfaceTool,frame:Transform3D,a:Vector2,b:Vector2,width:float)->void:
	var edge:Vector2=(b-a).orthogonal().normalized()*width*1.4
	quad(surface,frame,Vector3(a.x-edge.x,a.y-edge.y,.08),Vector3(b.x-edge.x,b.y-edge.y,.08),Vector3(b.x+edge.x,b.y+edge.y,.08),Vector3(a.x+edge.x,a.y+edge.y,.08))

static func chevron(surface:SurfaceTool,frame:Transform3D,x:float,turn:float)->void:
	var a:=Vector2(x-turn*1.35,2.)
	var b:=Vector2(x+turn*1.35,0.)
	var c:=Vector2(x-turn*1.35,-2.)
	var first:=(b-a).orthogonal().normalized()
	var last:=(c-b).orthogonal().normalized()
	var join:=(first+last).normalized()
	var width:=.58*1.4
	var middle:=join*(width/join.dot(first))
	var points:=[a,b,c]
	var edges:=[first*width,middle,last*width]
	# Two quads share one exact miter edge. No overlapping triangles or hot seam
	# at the point, and transverse UVs keep the glow continuous through the join.
	for i in range(2):
		var p:Vector2=points[i];var q:Vector2=points[i+1]
		var e:Vector2=edges[i];var f:Vector2=edges[i+1]
		quad(surface,frame,Vector3(p.x-e.x,p.y-e.y,.08),Vector3(q.x-f.x,q.y-f.y,.08),Vector3(q.x+f.x,q.y+f.y,.08),Vector3(p.x+e.x,p.y+e.y,.08))

static func build(parent:Node3D,track:RefCounted)->void:
	var panel:=SurfaceTool.new();panel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var neon:=SurfaceTool.new();neon.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mounts:=SurfaceTool.new();mounts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=0
	var descriptions:Array[Dictionary]=[]
	for planned in track.corner_warnings:
		var distance:float=planned.distance
		var n:Dictionary=track.sample(distance)
		var warning:Dictionary=planned.duplicate()
		var turn:float=warning.turn
		# Positive track lateral is the driver's right; panels sit outside the bend.
		var frame:=Transform3D(Basis(-n.frame.x,n.frame.y,-n.frame.z),Track.point(n,-turn*(n.width+10.),7.))
		var bottom:float=-5.4 if warning.exposed else -3.2
		if track.obstacles: track.obstacles.add_box(frame,AABB(Vector3(-8,bottom,-.1),Vector3(16,4.-bottom,.2)))
		quad(panel,frame,Vector3(-8,bottom,0),Vector3(8,bottom,0),Vector3(8,4,0),Vector3(-8,4,0))
		for j in range(3):
			var x:float=(j-1)*4.6
			neon.set_color(Color(warning.level/3.,float(j if turn>0 else 2-j)/3.,0.))
			chevron(neon,frame,x,turn)
		# One/two/three luminous ticks reinforce severity without relying on hue.
		neon.set_color(Color(warning.level/3.,0.,.4))
		for j in range(warning.level):
			var x:float=(j-(warning.level-1)*.5)*2.2
			stroke(neon,frame,Vector2(x-.7,3.2),Vector2(x+.7,3.2),.28)
		if warning.exposed:
			# Broken guardrail, open ledge and falling arrow: a separate cool-white
			# symbol, still legible while the warm chevrons sweep left or right.
			neon.set_color(Color(warning.level/3.,0.,1.))
			for side in [-1.,1.]:
				stroke(neon,frame,Vector2(side*1.4,-3.25),Vector2(side*3.2,-3.25),.22)
				stroke(neon,frame,Vector2(side*2.6,-3.25),Vector2(side*2.6,-4.3),.22)
			stroke(neon,frame,Vector2(0,-3.1),Vector2(0,-4.75),.24)
			stroke(neon,frame,Vector2(-.65,-4.1),Vector2(0,-4.75),.24)
			stroke(neon,frame,Vector2(.65,-4.1),Vector2(0,-4.75),.24)
		for x in [-5.5,5.5]:
			quad(mounts,frame,Vector3(x-.22,-7,0),Vector3(x+.22,-7,0),Vector3(x+.22,bottom,0),Vector3(x-.22,bottom,0))
		warning["frame"]=frame;warning["distance"]=distance;descriptions.append(warning)
		count+=1
	if count==0: return
	for entry in [[panel,Color("101c27"),0.],[neon,Color("ffbe50"),3.5],[mounts,Color("344955"),0.]]:
		var material:=StandardMaterial3D.new()
		material.albedo_color=entry[1]
		material.roughness=.7
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		var mesh:=MeshInstance3D.new()
		mesh.mesh=entry[0].commit();mesh.material_override=material
		if entry[2]>0:
			var animated:=ShaderMaterial.new();animated.shader=load("res://src/turn_marker.gdshader")
			mesh.material_override=animated;parent.set_meta("turn_marker_material",animated)
		mesh.layers=4
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mesh)
	parent.set_meta("turn_marker_count",count)
	parent.set_meta("turn_markers",descriptions)
