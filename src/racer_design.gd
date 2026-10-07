extends RefCounted
## Authored red-concept geometry. +Z is the nose; dimensions retain the racing hull envelope.
const HULL:=[Vector3(-3.65,.58,.38),Vector3(-2.7,.85,.66),Vector3(-.5,1.03,.95),Vector3(1.2,.82,.8),Vector3(3.5,.48,.42),Vector3(5.,.19,.16)]
const SOCKET:=Vector3(0.,1.15,-1.8)
static var panels:Dictionary={}

static func material(color:Color,metalness:float=.45,roughness:float=.3)->StandardMaterial3D:
	var result:=StandardMaterial3D.new();result.albedo_color=color
	result.metallic=metalness;result.roughness=roughness
	return result

static func triangle(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,normal:Vector3)->void:
	if (b-a).cross(c-a).length_squared()<.00000001: return
	if (b-a).cross(c-a).dot(normal)>0.: var swap:=b;b=c;c=swap
	for p in [a,b,c]:
		surface.set_normal(normal.normalized());surface.set_uv(Vector2(p.x,p.z)*.2);surface.add_vertex(p)

static func panel(parent:Node3D,name_value:String,points:Array,depth:Vector3,mat:Material,key:String="")->MeshInstance3D:
	# A closed extruded polygon, with explicit outward normals on both skins and edges.
	var mesh:MeshInstance3D=MeshInstance3D.new();mesh.name=name_value;mesh.material_override=mat
	if key.is_empty(): key=name_value
	if not panels.has(key):
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var center:=Vector3.ZERO
		for p in points: center+=p
		center/=points.size()
		var normal:=depth.normalized()
		for i in range(points.size()):
			var a:Vector3=points[i];var b:Vector3=points[(i+1)%points.size()]
			triangle(surface,center,a,b,normal)
			triangle(surface,center-depth,b-depth,a-depth,-normal)
			var edge_normal:Vector3=(b-a).cross(depth).normalized()
			if edge_normal.dot((a+b)*.5-center)<0.: edge_normal=-edge_normal
			triangle(surface,a,a-depth,b,edge_normal)
			triangle(surface,b,a-depth,b-depth,edge_normal)
		panels[key]=surface.commit()
	mesh.mesh=panels[key];parent.add_child(mesh);return mesh

## Airframe families share the engines, cockpit, hardpoint and control names;
## they differ in wings, fins, canopy, canards, winglets and livery.
const VARIANTS:=[
	{"name":"Arrow","hull":Vector2(1.,1.),"nose":5.,"girth":1.,"spoiler":false,"wing":[Vector2(1.4,1.45),Vector2(2.7,.85),Vector2(4.62,-1.68),Vector2(4.55,-2.05),Vector2(3.1,-2.05),Vector2(1.4,-1.7)],
		"elevon":Vector3(3.6,-2.11,0.),"wing_depth":.22,"winglet":0,"canards":false,"fin_cant":0.,"fin_height":1.,"fin_sweep":0.,
		"canopy":[Vector3(-.47,.48,.10),Vector3(.15,.60,.85),Vector3(1.15,.44,.79),Vector3(2.52,.075,.04)],"marking":Color(.898,.867,.816)},
	{"name":"Delta","hull":Vector2(1.18,.86),"nose":5.05,"girth":.94,"spoiler":false,"wing":[Vector2(1.4,2.55),Vector2(2.2,1.75),Vector2(4.66,-2.3),Vector2(4.56,-2.62),Vector2(2.9,-2.62),Vector2(1.4,-2.05)],
		"elevon":Vector3(3.62,-2.66,0.),"wing_depth":.2,"winglet":0,"canards":false,"fin_cant":.38,"fin_height":.78,"fin_sweep":.3,
		"canopy":[Vector3(-.6,.44,.10),Vector3(.2,.56,.75),Vector3(1.6,.42,.66),Vector3(3.0,.07,.04)],"marking":Color(.09,.1,.12)},
	{"name":"Raptor","hull":Vector2(.92,1.08),"nose":4.7,"girth":1.,"spoiler":false,"wing":[Vector2(1.4,.55),Vector2(3.4,.95),Vector2(4.62,1.3),Vector2(4.55,.82),Vector2(3.2,-.95),Vector2(1.4,-1.9)],
		"elevon":Vector3(2.6,-1.6,-.6),"wing_depth":.2,"winglet":0,"canards":true,"fin_cant":.12,"fin_height":1.12,"fin_sweep":.15,
		"canopy":[Vector3(-.47,.48,.10),Vector3(.15,.62,.82),Vector3(1.25,.46,.74),Vector3(2.7,.075,.04)],"marking":Color(.95,.74,.25)},
	{"name":"Brute","hull":Vector2(1.22,1.2),"nose":4.3,"girth":1.14,"spoiler":true,"wing":[Vector2(1.4,.9),Vector2(3.2,.35),Vector2(4.2,-1.25),Vector2(4.2,-2.05),Vector2(2.9,-2.05),Vector2(1.4,-1.75)],
		"elevon":Vector3(3.3,-2.11,0.),"wing_depth":.36,"winglet":-1,"canards":false,"fin_cant":0.,"fin_height":.92,"fin_sweep":-.1,
		"canopy":[Vector3(-.7,.5,.10),Vector3(-.2,.64,1.02),Vector3(.9,.56,.98),Vector3(2.0,.08,.04)],"marking":Color(.92,.9,.86)},
	{"name":"Needle","hull":Vector2(.8,.9),"nose":5.08,"girth":.86,"spoiler":false,"wing":[Vector2(1.4,1.0),Vector2(2.3,.55),Vector2(4.6,-2.85),Vector2(4.5,-3.15),Vector2(3.4,-3.05),Vector2(1.4,-1.75)],
		"elevon":Vector3(3.2,-2.98,.38),"wing_depth":.16,"winglet":1,"canards":false,"fin_cant":-.1,"fin_height":1.3,"fin_sweep":.45,
		"canopy":[Vector3(-1.3,.36,.08),Vector3(-.4,.46,.62),Vector3(1.3,.38,.56),Vector3(3.2,.06,.04)],"marking":Color(.07,.08,.1)},
]

static func variant_of(index:int)->Dictionary:
	return VARIANTS[posmod(index,VARIANTS.size())]

static func wing_points(side:int,y:float,variant:int=0)->Array:
	var result:=[]
	for point:Vector2 in variant_of(variant).wing: result.append(Vector3(side*point.x,y,point.y))
	return result

static func build(root:Node3D,paint:ShaderMaterial,loft:Callable,variant:int=0)->void:
	var design:=variant_of(variant)
	variant=posmod(variant,VARIANTS.size())
	root.set_meta("design",design.name)
	var dark:=material(Color("141d24"),.65,.34)
	var metal:=material(Color("72818a"),.85,.25)
	var black:=material(Color("070d12"),.25,.48)
	var glass:=material(Color("101e2a"),.68,.12)
	var hull:=[]
	var shape:Vector2=design.hull
	for i in range(HULL.size()):
		var section:Vector3=HULL[i]
		if i==HULL.size()-1: section.x=design.nose
		elif i==HULL.size()-2: section.x=lerpf(1.2,design.nose,.62)
		hull.append(Vector3(section.x,section.y*shape.x,section.z*shape.y))
	var body:MeshInstance3D=loft.call(root,"Body",hull,paint,Vector3.ZERO,true)
	body.set_instance_shader_parameter("face_surface",false)
	body.set_instance_shader_parameter("marking_style",1)
	root.set_meta("paint_materials",[paint])
	root.set_meta("damage_materials",[paint])
	# Recessed structural keel and cockpit surround make the painted shell feel substantial.
	loft.call(body,"Keel",[Vector3(-3.7,.3,.23),Vector3(-2.6,.8,.36),Vector3(1.2,.77,.32),Vector3(4.7,.2,.09)],dark,Vector3(0,-.27,0),true)
	loft.call(body,"CockpitFrame",[Vector3(-.6,.63,.12),Vector3(.2,.70,.20),Vector3(1.4,.53,.18),Vector3(2.7,.15,.06)],dark,Vector3(0,.69,0),true)
	var canopy:MeshInstance3D=loft.call(root,"Canopy",design.canopy,glass,Vector3(0,.71,0),true)
	loft.call(body,"RearCooling",[Vector3(-3.67,.5,.27),Vector3(-3.66,.5,.27)],dark,Vector3.ZERO,true)
	grille(body,"RearGrille",Vector3(0,.11,-3.69),Vector3(.84,.035,.025),3,Vector3(0,-.09,0),metal)
	for side in [-1,1]:
		var flank:=paint.duplicate() as ShaderMaterial
		flank.set_shader_parameter("wear_offset",Vector3(side*.379,side*.173,side*.617))
		root.get_meta("paint_materials").append(flank)
		root.get_meta("damage_materials").append(flank)
		var girth:float=design.girth
		var pod:=[]
		for section in [Vector3(-3.68,.69,.92),Vector3(-3.,.91,1.24),Vector3(-1.4,.94,1.32),Vector3(.9,.80,1.15),Vector3(2.25,.56,.83),Vector3(2.8,.40,.60)]:
			# The rear ring stays nozzle-sized; the pod swells or slims ahead of it.
			var swell:=lerpf(1.,girth,smoothstep(-3.68,-2.6,section.x))
			pod.append(Vector3(section.x,section.y*swell,section.z*swell))
		var nacelle:MeshInstance3D=loft.call(root,"Nacelle%d"%side,pod,flank,Vector3(side*2.45,.02,0),false)
		nacelle.set_instance_shader_parameter("face_surface",true);nacelle.set_instance_shader_parameter("face_side",float(side))
		nacelle.set_instance_shader_parameter("marking_style",2)
		# Dark forward-facing intake is visibly recessed into a machined lip.
		loft.call(nacelle,"IntakeLip",[Vector3(2.73,.435,.65),Vector3(2.85,.43,.64),Vector3(2.851,.35,.49),Vector3(2.56,.35,.49)],metal,Vector3.ZERO,false)
		loft.call(nacelle,"IntakeWell",[Vector3(2.50,.35,.49),Vector3(2.52,.35,.49)],black,Vector3.ZERO,true)
		loft.call(nacelle,"TurbineHousing",[Vector3(-3.73,.72,1.05),Vector3(-3.1,.89,1.27)],dark,Vector3.ZERO,false)
		grille(nacelle,"IntakeGrille",Vector3(0,.12,2.66),Vector3(.52,.035,.035),3,Vector3(0,-.095,0),metal)
		grille(nacelle,"EngineVents",Vector3(-side*.60,.44,-.65),Vector3(.24,.055,.07),7,Vector3(0,.018,-.15),dark)
		# Structural inboard engine struts remain visible through the open channels.
		for z in [-2.1,.35]:
			var strut:=BoxMesh.new();strut.size=Vector3(1.3,.21,.36)
			var node:=MeshInstance3D.new();node.mesh=strut;node.material_override=dark;node.position=Vector3(-side*.98,-.18,z);nacelle.add_child(node)
		var depth:float=design.wing_depth
		var fixed_wing:=panel(root,"Wing%d"%side,wing_points(side,.08+depth-.22,variant),Vector3(0,depth,0),paint,"Wing%d/%d"%[side,variant])
		fixed_wing.set_instance_shader_parameter("marking_style",3)
		var wing:=Node3D.new();wing.name="WingControlL" if side<0 else "WingControlR"
		var hinge:Vector3=design.elevon
		wing.position=Vector3(side*hinge.x,.08,hinge.y);wing.rotation.y=side*hinge.z;root.add_child(wing)
		panel(wing,"Elevon%d"%side,[Vector3(-.88,0,0),Vector3(.88,0,0),Vector3(.80,0,-.66),Vector3(-.62,0,-.80)],Vector3(0,.15,0),paint)
		var tip:Vector2=design.wing[2]
		if design.winglet!=0:
			# Upturned or drooped wingtip fins, flush with the wing's leading tip.
			var up:float=design.winglet
			var y:=.08+depth-.22
			var fence:=panel(root,"Winglet%d"%side,[Vector3(side*(tip.x-.02),y,tip.y+.1),Vector3(side*(tip.x+.02),y+up*1.05,tip.y-.75),Vector3(side*(tip.x+.02),y+up*1.05,tip.y-1.15),Vector3(side*(tip.x-.02),y,tip.y-.95)],Vector3(.08,0,0),paint,"Winglet%d/%d"%[side,variant])
			fence.set_instance_shader_parameter("marking_style",4)
		if design.canards:
			panel(root,"Canard%d"%side,[Vector3(side*.4,.42,4.1),Vector3(side*1.75,.42,3.35),Vector3(side*1.78,.42,3.05),Vector3(side*.4,.42,3.25)],Vector3(0,.09,0),paint,"Canard%d"%side).set_instance_shader_parameter("marking_style",3)
		# Stationary swept fin with an independently hinged rear rudder.
		var fin_x:float=side*2.6
		var tall:float=design.fin_height
		var sweep:float=design.fin_sweep
		var fixed_fin:=panel(nacelle,"FixedFin%d"%side,[Vector3(side*.05,.63,-1.2-sweep*.6),Vector3(side*.32,.63+1.37*tall,-2.56-sweep),Vector3(side*.33,.6+1.37*tall,-2.88-sweep*.6),Vector3(side*.1,.62,-2.88)],Vector3(.10,0,0),paint,"FixedFin%d/%d"%[side,variant])
		fixed_fin.rotation.z=-side*design.fin_cant
		var rudder:=Node3D.new();rudder.name="RudderL" if side<0 else "RudderR"
		rudder.position=Vector3(fin_x,.64,-2.94);rudder.rotation.z=-side*design.fin_cant;root.add_child(rudder)
		var tail:=panel(rudder,"TailFin%d"%side,[Vector3(0,0,0),Vector3(side*.18,1.32*tall,-sweep*.4),Vector3(side*.2,1.37*tall,-.43-sweep*.4),Vector3(0,0,-.59)],Vector3(.10,0,0),paint,"TailFin%d/%d"%[side,variant])
		tail.set_instance_shader_parameter("marking_style",4)
		var brake:=Node3D.new();brake.name="Airbrake%d"%side;brake.position=Vector3(side*2.45,.98,-.7);root.add_child(brake)
		panel(brake,"Door%d"%side,[Vector3(-.50,0,.05),Vector3(.5,0,.05),Vector3(.56,0,-1.26),Vector3(-.56,0,-1.26)],Vector3(0,.075,0),paint)
		panel(brake,"BrakeInset%d"%side,[Vector3(-.36,.012,-.15),Vector3(.36,.012,-.15),Vector3(.4,.012,-1.08),Vector3(-.4,.012,-1.08)],Vector3(0,.01,0),dark)
		grille(brake,"BrakeCooling",Vector3(0,.035,-.25),Vector3(.62,.025,.045),5,Vector3(0,0,-.16),metal)
		var strip:=material(Color("ff693d"),.25,.23);strip.emission_enabled=true;strip.emission=Color("ff5c24");strip.emission_energy_multiplier=.7
		loft.call(root,"Light%d"%side,[Vector3(-2.9,.032,.04),Vector3(-.8,.032,.04)],strip,Vector3(side*3.24,.45,0),true)
	if design.spoiler:
		# A raised rear wing on two pylons, clear of the moving rudders below it.
		var wing:=panel(root,"Spoiler",[Vector3(-3.35,2.24,-3.05),Vector3(3.35,2.24,-3.05),Vector3(3.45,2.24,-3.95),Vector3(-3.45,2.24,-3.95)],Vector3(0,.16,0),paint,"Spoiler")
		wing.set_instance_shader_parameter("marking_style",3)
		for side in [-1,1]:
			panel(root,"Pylon%d"%side,[Vector3(side*1.62,.9,-3.15),Vector3(side*1.62,2.1,-3.35),Vector3(side*1.62,2.1,-3.8),Vector3(side*1.62,.9,-3.55)],Vector3(.12,0,0),dark,"Pylon%d"%side)
			panel(root,"Endplate%d"%side,[Vector3(side*3.45,1.75,-2.9),Vector3(side*3.45,2.45,-2.95),Vector3(side*3.45,2.45,-4.05),Vector3(side*3.45,1.9,-4.0)],Vector3(.08,0,0),paint,"Endplate%d"%side).set_instance_shader_parameter("marking_style",4)
	# One universal quick-release shoe. Weapon VFX use the same socket coordinates.
	var socket:=Node3D.new();socket.name="WeaponSocket";socket.position=SOCKET;body.add_child(socket)
	loft.call(socket,"MountBase",[Vector3(-.87,.48,.16),Vector3(-.7,.67,.18),Vector3(.7,.67,.18),Vector3(.86,.48,.16)],dark,Vector3(0,-.43,0),true)
	for side in [-1,1]:
		loft.call(socket,"MountRail%d"%side,[Vector3(-.75,.07,.12),Vector3(.75,.07,.12)],metal,Vector3(side*.46,-.30,0),true)
	batch_details(root)

static func batch_details(parent:Node3D)->void:
	# Keep independent crash/control parts but combine repeated trim within each part.
	for child in parent.get_children():
		if child is Node3D: batch_details(child)
	if parent.get_parent()==null: return
	var groups:Dictionary={}
	for child in parent.get_children():
		if child is MeshInstance3D and child.get_child_count()==0:
			var mat:Material=child.material_override
			if not groups.has(mat): groups[mat]=[]
			groups[mat].append(child)
	for mat in groups:
		var nodes:Array=groups[mat]
		if nodes.size()<2: continue
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for node in nodes: surface.append_from(node.mesh,0,node.transform)
		var combined:=MeshInstance3D.new();combined.name=nodes[0].name;combined.mesh=surface.commit();combined.material_override=mat
		for node in nodes: parent.remove_child(node);node.free()
		parent.add_child(combined)

static func grille(parent:Node3D,name_value:String,position:Vector3,size:Vector3,count:int,step:Vector3,mat:Material)->void:
	var shape:=BoxMesh.new();shape.size=size
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(count): surface.append_from(shape,0,Transform3D(Basis.IDENTITY,step*i))
	var node:=MeshInstance3D.new();node.name=name_value;node.mesh=surface.commit();node.material_override=mat;node.position=position;parent.add_child(node)

static func nozzle_detail(collar:Node3D)->void:
	# A single combined mesh for all petals; local torus axis is Y.
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(20):
		var a:float=TAU*i/20.;var b:float=TAU*(i+.82)/20.
		var p:=Vector3(cos(a)*.54,-.02,sin(a)*.54);var q:=Vector3(cos(b)*.54,-.02,sin(b)*.54)
		var r:=Vector3(cos(b+.10)*.30,.34,sin(b+.10)*.30);var s:=Vector3(cos(a+.10)*.30,.34,sin(a+.10)*.30)
		var n:=Vector3(-cos(a)*.4,-1.,-sin(a)*.4).normalized()
		triangle(surface,p,q,r,n);triangle(surface,p,r,s,n)
	var petals:=MeshInstance3D.new();petals.name="NozzlePetals";petals.mesh=surface.commit();petals.material_override=material(Color("46545e"),.9,.3);collar.add_child(petals)
	var throat:=MeshInstance3D.new();var bowl:=CylinderMesh.new();bowl.top_radius=.5;bowl.bottom_radius=.5;bowl.height=.02;bowl.radial_segments=24
	throat.mesh=bowl;throat.position.y=.37;throat.material_override=material(Color("070b10"),.25,.4);collar.add_child(throat)
