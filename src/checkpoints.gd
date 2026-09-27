extends RefCounted
## Sparse physical gates; open space between them is legal shortcut territory.
var track:RefCounted
var gates:Array[Dictionary]=[]

func _init(course:RefCounted)->void:
	track=course
	for loop in track.loops:
		add_at((loop.start+loop.end)*.5,true,loop.start)
	for component in track.components:
		if component.kind=="spiral": add_at(lerpf(component.start,component.end,.48),true,component.start)
	for u in [.25,.55,.80]:
		if gates.any(func(g):return absf(g.u-u)<.14): continue
		add_at(u,false,u)
	gates.sort_custom(func(a,b):return a.distance<b.distance)

func add_at(u:float,loop_gate:bool,entry:float)->void:
	var best:=-1;var error:=INF
	for i in range(track.nodes.size()):
		var n:Dictionary=track.nodes[i]
		if n.air_gap or (not loop_gate and n.loop): continue
		var difference:=absf(n.u-u)
		if difference<error: error=difference;best=i
	if best<0: return
	var n:Dictionary=track.nodes[best]
	var respawn:float=best*track.step-100.
	if loop_gate:
		for i in range(best):
			if track.nodes[i].u>=entry: respawn=i*track.step-100.;break
	var height:=24. if loop_gate else 32.
	if n.tunnel: height=13.
	elif n.shape_angle>2.: height=2.*n.width/n.shape_angle+6.
	gates.append({"u":n.u,"distance":best*track.step,"frame":Transform3D(n.frame,n.p),
		"width":n.width+6.,"height":height,"loop":loop_gate,"respawn":maxf(0.,respawn)})

func initialize(p:Dictionary)->void:
	p.checkpoint_index=0;p.checkpoint_missed=false;p.checkpoint_flash=0.

func advance(p:Dictionary,to:Vector3)->void:
	if p.checkpoint_index>=gates.size() or not p.has("checkpoint_before") or p.crashed or p.recovery>0.: return
	var gate:Dictionary=gates[p.checkpoint_index]
	var inverse:Transform3D=gate.frame.affine_inverse()
	var before:Vector3=inverse*Vector3(p.checkpoint_before)
	var after:Vector3=inverse*to
	if before.z>=0. or after.z<0. or Vector3(p.checkpoint_before).distance_to(to)>120.: return
	var crossing:=before.lerp(after,-before.z/(after.z-before.z))
	if absf(crossing.x)>gate.width or crossing.y< -4. or crossing.y>gate.height: return
	p.checkpoint_index+=1;p.checkpoint_missed=false;p.checkpoint_flash=.7
	# A checkpoint also anchors airborne route projection for the next segment.
	if p.airborne: p.distance=maxf(p.distance,(p.lap-1)*track.length+gate.distance)

func complete(p:Dictionary)->bool:
	return p.checkpoint_index>=gates.size()

func progress(p:Dictionary)->float:
	var limit:float=p.lap*track.length if complete(p) else (p.lap-1)*track.length+gates[p.checkpoint_index].distance
	return minf(p.distance,limit)

func return_distance(p:Dictionary)->float:
	return (p.lap-1)*track.length+gates[mini(p.checkpoint_index,gates.size()-1)].respawn

func build(parent:Node3D)->void:
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color("8cebdd");material.emission_enabled=true
	material.emission=Color("8cebdd");material.emission_energy_multiplier=1.4
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(gates.size()):
		var gate:Dictionary=gates[i]
		# Open, segmented luminous frame. No collision wall and no filled plane.
		for side in [-1.,1.]:
			for y in range(0,int(gate.height),5):
				var box:=BoxMesh.new();box.size=Vector3(.25,3.,.25)
				surface.append_from(box,0,gate.frame*Transform3D(Basis.IDENTITY,Vector3(side*gate.width,y+1.5,0.)))
		for x in range(-int(gate.width),int(gate.width),6):
			var box:=BoxMesh.new();box.size=Vector3(3.8,.25,.25)
			surface.append_from(box,0,gate.frame*Transform3D(Basis.IDENTITY,Vector3(x+2.,gate.height,0.)))
		var label:=Label3D.new();label.text="CHECKPOINT  %d / %d"%[i+1,gates.size()]
		label.font_size=64;label.pixel_size=.024;label.modulate=Color("c5fff4")
		label.no_depth_test=false;label.outline_size=4
		label.transform=gate.frame*Transform3D(Basis(Vector3.UP,PI),Vector3(0.,gate.height+2.,0.))
		parent.add_child(label)
	if gates.is_empty(): return
	var mesh:=MeshInstance3D.new();mesh.name="CheckpointFrames"
	mesh.mesh=surface.commit();mesh.material_override=material
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.gi_mode=GeometryInstance3D.GI_MODE_DISABLED;parent.add_child(mesh)
