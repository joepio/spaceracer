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
var fire:MultiMesh
var fire_mesh:MultiMeshInstance3D
var material_sources:Array[Dictionary]=[]
var flash:OmniLight3D
var blast:Node3D

func prepare_fragment(node:Node3D,frame:Transform3D,bounds:Array[AABB])->void:
	frame=frame*node.transform
	if node is MeshInstance3D:
		bounds.append(frame*node.mesh.get_aabb())
		node.layers=2
		var original:Material=node.material_override
		var material:=ShaderMaterial.new();material.shader=load("res://src/wreck_surface.gdshader")
		material.set_shader_parameter("seed",float(node.name.hash()%997)*.073)
		material_sources.append({"original":original,"burnt":material})
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
	# Split the new hull on its actual authored section boundaries.
	var sections:Array=Ship.Design.HULL
	for entry in [["HullRear",sections.slice(0,3)],["HullMiddle",sections.slice(2,5)],["HullNose",sections.slice(4,6)]]:
		var section:MeshInstance3D=Ship.loft(hull,entry[0],entry[1],paint,Vector3.ZERO,true)
		if entry[0]=="HullRear":
			for child in source_ship.get_node("Body").get_children(): section.add_child(child.duplicate())
		fragment(section,parts)
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
	# Source paint may have changed since the pooled wreck was created (GameNight
	# colors, team colors, etc.). Copy the current color at the actual impact.
	for entry in material_sources:
		var tint:=Color(.18,.22,.27);var metalness:=.4
		if entry.original is ShaderMaterial:
			var value:Variant=entry.original.get_shader_parameter("tint")
			if value is Color: tint=value
			elif value is Vector3: tint=Color(value.x,value.y,value.z)
		elif entry.original is StandardMaterial3D:
			var color:Color=entry.original.albedo_color
			tint=color;metalness=entry.original.metallic
		entry.burnt.set_shader_parameter("tint",tint)
		entry.burnt.set_shader_parameter("metalness",metalness)
	p.wreck=Wreck.new(parts,p)

func _ready()->void:
	# Small 3D flames on recognizable fragments; no rectangular confetti.
	fire=MultiMesh.new();fire.transform_format=MultiMesh.TRANSFORM_3D;fire.use_custom_data=true
	var shape:=SphereMesh.new();shape.radius=.5;shape.height=1.;shape.radial_segments=12;shape.rings=7
	fire.mesh=shape;fire.instance_count=12
	for i in range(12): fire.set_instance_custom_data(i,Color(fposmod(i*.618,1.),0,0,0))
	fire_mesh=MultiMeshInstance3D.new();fire_mesh.multimesh=fire;fire_mesh.layers=2
	fire_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new();material.shader=load("res://src/wreck_fire.gdshader")
	fire_mesh.material_override=material;add_child(fire_mesh)
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
	fire_mesh.visible=p.crashed and p.wreck!=null and age<1.95
	fire_mesh.material_override.set_shader_parameter("age",age)
	if not visible: return
	if not p.crashed: return # Smoke completes its fade at the impact, after the craft respawns.
	if p.wreck!=null:
		for i in range(fragments.size()): fragments[i].global_transform=p.wreck.pieces[i].frame
	if p.wreck!=null:
		var burning_parts:=[0,1,4,5] # Rear/mid hull and the two engine housings.
		for i in range(12):
			var piece:Dictionary=p.wreck.pieces[burning_parts[i/3]]
			var tongue:=i%3;var phase:=age*13.+i*2.4
			var height:=1.1+(sin(phase)*.5+.5)*.8+tongue*.25
			var attachment:Vector3=piece.frame*Vector3((tongue-1)*.28,piece.half.y*.6,0.)
			var at:=to_local(attachment)+Vector3.UP*height*.32
			var stretch:=Basis.IDENTITY.scaled(Vector3(.6,height,.6))
			fire.set_instance_transform(i,Transform3D(stretch,at))
