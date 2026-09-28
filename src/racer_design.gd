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

static func panel(parent:Node3D,name_value:String,points:Array,depth:Vector3,mat:Material)->MeshInstance3D:
	# A closed extruded polygon, with explicit outward normals on both skins and edges.
	var mesh:MeshInstance3D=MeshInstance3D.new();mesh.name=name_value;mesh.material_override=mat
	if not panels.has(name_value):
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
		panels[name_value]=surface.commit()
	mesh.mesh=panels[name_value];parent.add_child(mesh);return mesh

static func wing_points(side:int,y:float)->Array:
	return [Vector3(side*1.4,y,1.45),Vector3(side*2.7,y,.85),Vector3(side*4.62,y,-1.68),Vector3(side*4.55,y,-2.05),Vector3(side*3.1,y,-2.05),Vector3(side*1.4,y,-1.7)]

static func build(root:Node3D,paint:ShaderMaterial,loft:Callable)->void:
	var dark:=material(Color("141d24"),.65,.34)
	var metal:=material(Color("72818a"),.85,.25)
	var black:=material(Color("070d12"),.25,.48)
	var glass:=material(Color("101e2a"),.68,.12)
	var body:MeshInstance3D=loft.call(root,"Body",HULL,paint,Vector3.ZERO,true)
	body.set_instance_shader_parameter("face_surface",false)
	body.set_instance_shader_parameter("marking_style",1)
	root.set_meta("paint_materials",[paint])
	root.set_meta("damage_materials",[paint])
	# Recessed structural keel and cockpit surround make the painted shell feel substantial.
	loft.call(body,"Keel",[Vector3(-3.7,.3,.23),Vector3(-2.6,.8,.36),Vector3(1.2,.77,.32),Vector3(4.7,.2,.09)],dark,Vector3(0,-.27,0),true)
	loft.call(body,"CockpitFrame",[Vector3(-.6,.63,.12),Vector3(.2,.70,.20),Vector3(1.4,.53,.18),Vector3(2.7,.15,.06)],dark,Vector3(0,.69,0),true)
	var canopy:MeshInstance3D=loft.call(root,"Canopy",[Vector3(-.47,.48,.10),Vector3(.15,.60,.85),Vector3(1.15,.44,.79),Vector3(2.52,.075,.04)],glass,Vector3(0,.71,0),true)
	loft.call(body,"RearCooling",[Vector3(-3.67,.5,.27),Vector3(-3.66,.5,.27)],dark,Vector3.ZERO,true)
	grille(body,"RearGrille",Vector3(0,.11,-3.69),Vector3(.84,.035,.025),3,Vector3(0,-.09,0),metal)
	for side in [-1,1]:
		var flank:=paint.duplicate() as ShaderMaterial
		flank.set_shader_parameter("wear_offset",Vector3(side*.379,side*.173,side*.617))
		root.get_meta("paint_materials").append(flank)
		root.get_meta("damage_materials").append(flank)
		var nacelle:MeshInstance3D=loft.call(root,"Nacelle%d"%side,[Vector3(-3.68,.69,.92),Vector3(-3.,.91,1.24),Vector3(-1.4,.94,1.32),Vector3(.9,.80,1.15),Vector3(2.25,.56,.83),Vector3(2.8,.40,.60)],flank,Vector3(side*2.45,.02,0),false)
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
		var fixed_wing:=panel(root,"Wing%d"%side,wing_points(side,.08),Vector3(0,.22,0),paint)
		fixed_wing.set_instance_shader_parameter("marking_style",3)
		var wing:=Node3D.new();wing.name="WingControlL" if side<0 else "WingControlR"
		wing.position=Vector3(side*3.6,.08,-2.11);root.add_child(wing)
		panel(wing,"Elevon%d"%side,[Vector3(-.88,0,0),Vector3(.88,0,0),Vector3(.80,0,-.66),Vector3(-.62,0,-.80)],Vector3(0,.15,0),paint)
		# Stationary swept fin with an independently hinged rear rudder.
		var fin_x:float=side*2.6
		panel(nacelle,"FixedFin%d"%side,[Vector3(side*.05,.63,-1.2),Vector3(side*.32,2.,-2.56),Vector3(side*.33,1.97,-2.88),Vector3(side*.1,.62,-2.88)],Vector3(.10,0,0),paint)
		var rudder:=Node3D.new();rudder.name="RudderL" if side<0 else "RudderR"
		rudder.position=Vector3(fin_x,.64,-2.94);root.add_child(rudder)
		var tail:=panel(rudder,"TailFin%d"%side,[Vector3(0,0,0),Vector3(side*.18,1.32,0),Vector3(side*.2,1.37,-.43),Vector3(0,0,-.59)],Vector3(.10,0,0),paint)
		tail.set_instance_shader_parameter("marking_style",4)
		var brake:=Node3D.new();brake.name="Airbrake%d"%side;brake.position=Vector3(side*2.45,.98,-.7);root.add_child(brake)
		panel(brake,"Door%d"%side,[Vector3(-.50,0,.05),Vector3(.5,0,.05),Vector3(.56,0,-1.26),Vector3(-.56,0,-1.26)],Vector3(0,.075,0),paint)
		panel(brake,"BrakeInset%d"%side,[Vector3(-.36,.012,-.15),Vector3(.36,.012,-.15),Vector3(.4,.012,-1.08),Vector3(-.4,.012,-1.08)],Vector3(0,.01,0),dark)
		grille(brake,"BrakeCooling",Vector3(0,.035,-.25),Vector3(.62,.025,.045),5,Vector3(0,0,-.16),metal)
		var strip:=material(Color("ff693d"),.25,.23);strip.emission_enabled=true;strip.emission=Color("ff5c24");strip.emission_energy_multiplier=.7
		loft.call(root,"Light%d"%side,[Vector3(-2.9,.032,.04),Vector3(-.8,.032,.04)],strip,Vector3(side*3.24,.45,0),true)
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
