extends RefCounted
## Short surface discharges on engine housings and wing roots, never a hull shell.
static var shared_shape:ArrayMesh
static func shape()->ArrayMesh:
	if shared_shape: return shared_shape
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paths:Array=[]
	for side in [-1.,1.]:
		paths.append([Vector3(side*2.05,.98,-.35),Vector3(side*2.75,1.,-1.3)])
		paths.append([Vector3(side*2.5,.94,-2.3),Vector3(side*2.75,.80,-3.15)])
		paths.append([Vector3(side*3.4,.12,-1.55),Vector3(side*4.15,.12,-1.8)])
		paths.append([Vector3(side*1.1,.15,.2),Vector3(side*1.7,.6,.35)])
	for id in range(paths.size()):
		var from:Vector3=paths[id][0];var to:Vector3=paths[id][1]
		var tangent:Vector3=(to-from).normalized()
		for segment in range(8):
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(0,1),Vector2(1,0),Vector2(1,1)]:
				var t:float=(segment+corner.y)/8.
				surface.set_uv(Vector2(corner.x,t))
				surface.set_color(Color(float(id)/8.,0.,0.))
				surface.set_normal(Vector3.UP)
				surface.set_tangent(Plane(tangent,1.))
				# Non-degenerate input ribbons survive mesh optimization before the shader
				# turns their width toward each split-screen camera.
				surface.add_vertex(from.lerp(to,t)+Vector3.UP*(sin(t*PI)*.18+(corner.x*2.-1.)*.075))
	shared_shape=surface.commit()
	return shared_shape
