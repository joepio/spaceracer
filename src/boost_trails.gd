extends Node3D
## Short exposure streaks follow the actual path, including corners and rolls.
const POINTS:=32
const LIFE:=.38
static var ribbon:Mesh
var strands:Array[MeshInstance3D]=[]
var history:Array[Dictionary]=[]
var last_time:=-1.

func _ready()->void:
	if ribbon==null:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for segment in range(POINTS-1):
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(0,1),Vector2(1,0),Vector2(1,1)]:
				surface.set_uv(Vector2(corner.x,(segment+corner.y)/float(POINTS-1)))
				surface.add_vertex(Vector3.ZERO)
		ribbon=surface.commit()
	for side in [-1,1]:
		var strand:=MeshInstance3D.new();strand.mesh=ribbon
		var material:=ShaderMaterial.new();material.shader=load("res://src/boost_trails.gdshader")
		strand.material_override=material;strand.layers=2
		strand.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strand.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
		add_child(strand);strands.append(strand)
	visible=false

func update_trail(frame:Transform3D,p:Dictionary,time:float,tint:Color)->void:
	if time<last_time or p.crashed or p.recovery>0.: history.clear()
	var boosting:bool=(p.boost>0. or p.on_pad) and p.braking<.05 and not p.airborne and p.thrust>0. and not p.crashed and p.recovery<=0. and not p.finished
	if not history.is_empty():
		var elapsed:=maxf(0.,time-float(history[0].time))
		if frame.origin.distance_to(history[0].pose.origin)>maxf(30.,absf(p.speed)*elapsed*2.+10.): history.clear()
	if boosting and (history.is_empty() or time-float(history[0].time)>=1./90.):
		history.push_front({"pose":frame,"time":time})
	while not history.is_empty() and (time-float(history.back().time)>LIFE or history.size()>POINTS): history.pop_back()
	last_time=time;visible=history.size()>1
	if not visible: return
	for side in range(2):
		var points:=PackedVector3Array();var ages:=PackedFloat32Array()
		var bounds:=AABB(frame.origin,Vector3.ZERO)
		for index in range(POINTS):
			var sample:Dictionary=history[mini(index,history.size()-1)]
			var sample_frame:Transform3D=frame if index==0 and boosting else sample.pose
			var point:Vector3=sample_frame*Vector3(-2.45 if side==0 else 2.45,.4,-3.)
			points.append(point);ages.append((time-float(sample.time))/LIFE);bounds=bounds.expand(point)
		strands[side].custom_aabb=bounds.grow(2.)
		var material:ShaderMaterial=strands[side].material_override
		material.set_shader_parameter("points",points)
		material.set_shader_parameter("ages",ages)
		material.set_shader_parameter("point_count",history.size())
		material.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
