extends Node3D
## One bounded explosion per craft, driven by the pausable race clock.
const Ship=preload("res://src/ship.gd")
const Wreck=preload("res://src/wreck.gd")
const Blast=preload("res://src/blast_vfx.gd")
var source_ship:Node3D
var fragments:Array[Node3D]=[]
var templates:Array[Dictionary]=[]
var serial:=-1
var started:=0.
var debris:MultiMesh
var flash:OmniLight3D
var blast:Node3D

static func prepare_fragment(node:Node3D,frame:Transform3D,bounds:Array[AABB])->void:
	frame=frame*node.transform
	if node is MeshInstance3D:
		bounds.append(frame*node.mesh.get_aabb())
		node.layers=2
		var material:Material=node.material_override.duplicate()
		if material is ShaderMaterial: material.set_shader_parameter("wrecked",.7)
		elif material is StandardMaterial3D:
			material.emission_enabled=false
			material.albedo_color=material.albedo_color.lerp(Color("28252a"),.3)
		node.material_override=material
	for child in node.get_children():
		if child is Node3D: prepare_fragment(child,frame,bounds)

func fragment(source:Node3D,parts:Array)->void:
	var holder:=Node3D.new();holder.name="Fragment_"+source.name
	add_child(holder)
	var copy:=source.duplicate() as Node3D
	holder.add_child(copy)
	var bounds:Array[AABB]=[]
	prepare_fragment(copy,Transform3D.IDENTITY,bounds)
	var merged:AABB=bounds[0]
	for item in bounds.slice(1): merged=merged.merge(item)
	var center:=merged.get_center()
	copy.position-=center
	parts.append({"frame":Transform3D(Basis.IDENTITY,center),"half":merged.size*.5,
		"source":source if source.is_inside_tree() else null,"copy":copy})
	fragments.append(holder)

func configure(ship:Node3D)->void:
	source_ship=ship
	var parts:Array=[]
	var hull:=Node3D.new()
	var paint:Material=source_ship.get_node("Body").material_override
	# Split the existing loft at its section boundaries, with sealed broken ends.
	for entry in [["HullRear",[Vector3(-3.4,.1,.1),Vector3(-2.7,1.5,.8),Vector3(.2,1.65,1.2)]],
		["HullMiddle",[Vector3(.2,1.65,1.2),Vector3(2.8,.8,.4)]],
		["HullNose",[Vector3(2.8,.8,.4),Vector3(5,.025,.03)]]]:
		fragment(Ship.loft(hull,entry[0],entry[1],paint,Vector3.ZERO,true),parts)
	hull.free()
	for name_value in ["Canopy","Nacelle-1","Nacelle1","Wing-1","Wing1","WingControlL","WingControlR","RudderL","RudderR","Nozzle-1","Nozzle1","Airbrake-1","Airbrake1"]:
		fragment(source_ship.get_node(name_value),parts)
	templates.assign(parts)

func break_ship(p:Dictionary)->void:
	if not is_instance_valid(source_ship): return
	var parts:Array=[]
	for template in templates:
		if is_instance_valid(template.source):
			template.copy.transform=template.source.transform
			template.copy.position-=template.frame.origin
		parts.append({"frame":source_ship.global_transform*template.frame,"half":template.half})
	p.wreck=Wreck.new(parts,p)

func batch(count:int,mesh:Mesh)->MultiMesh:
	var data:=MultiMesh.new()
	data.transform_format=MultiMesh.TRANSFORM_3D;data.use_colors=true
	data.mesh=mesh;data.instance_count=count
	var renderer:=MultiMeshInstance3D.new()
	renderer.multimesh=data;renderer.layers=2
	renderer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.roughness=.95
	renderer.material_override=material
	add_child(renderer)
	return data

func _ready()->void:
	debris=batch(22,BoxMesh.new())
	blast=Blast.new();add_child(blast);flash=blast.flash
	visible=false

func update(p:Dictionary,time:float)->void:
	if p.crash_id!=serial:
		serial=p.crash_id;started=time
		position=p.air_position
		if p.crashed:
			break_ship(p)
			blast.show_blast(p.slot*100000+p.crash_id,Vector3.ZERO,0.,18.)
	var age:=maxf(0.,time-started)
	blast.render_at(age)
	visible=(p.crashed and serial>0) or blast.visible
	for fragment_node in fragments: fragment_node.visible=p.crashed
	debris.visible_instance_count=22 if p.crashed else 0
	if not visible: return
	if not p.crashed: return # Smoke completes its fade at the impact, after the craft respawns.
	if p.wreck!=null:
		for i in range(fragments.size()): fragments[i].global_transform=p.wreck.pieces[i].frame
	for i in range(22):
		var velocity:=Vector3(sin(i*4.1)*25.,9.+i%8*2.,cos(i*2.4)*25.)
		var at:=velocity*age+Vector3.DOWN*age*age*10.
		var basis:=Basis(Vector3(1.,.7,.3).normalized(),age*(i%5+2)).scaled(Vector3(.3,.25,1.+i%3*.5))
		debris.set_instance_transform(i,Transform3D(basis,at))
		debris.set_instance_color(i,Color(.14,.12,.1,maxf(0.,1.-age/2.5)))
