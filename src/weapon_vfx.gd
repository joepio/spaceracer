extends Node3D
const Weapons=preload("res://src/weapons.gd")
const Blast=preload("res://src/blast_vfx.gd")
const Ship=preload("res://src/ship.gd")
const Impact=preload("res://src/impact_vfx.gd")
const EmpSparks=preload("res://src/emp_sparks.gd")
var race:RefCounted
var cores:MultiMesh
var missile_nodes:Dictionary={}
var fading_trails:Array[Dictionary]=[]
var bomb_nodes:Dictionary={}
var rail_effects:Array[Node3D]=[]
var turrets:Array[Node3D]=[]
var mounts:Array[Dictionary]=[]
var impacts:Array[Node3D]=[]
var warp_wakes:Array[MeshInstance3D]=[]
var warp_lenses:Array[MeshInstance3D]=[]
var tracers:Array[MeshInstance3D]=[]
var shot_frame:=-1
var presented_shots:Array[Dictionary]=[]
var explosions:Array[Node3D]=[]
var blast_lights:Array[OmniLight3D]=[]
static var trail_shape:ArrayMesh
var emp_fields:Array[MeshInstance3D]=[]
var emp_rings:Array[MeshInstance3D]=[]
var emp_arcs:Array[MeshInstance3D]=[]
var pickup_bases:Array[MeshInstance3D]=[]
var pickup_echoes:Array[MeshInstance3D]=[]
var pickup_halos:Array[MeshInstance3D]=[]
var pickup_lights:Array[OmniLight3D]=[]
var bump_jets:Array[Node3D]=[]
var bump_material:ShaderMaterial
var laser_material:StandardMaterial3D
var steel:StandardMaterial3D
var mint:StandardMaterial3D
var flame:StandardMaterial3D

static func material(color:Color,glow:float=0.)->StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.35;m.metallic=.45
	if glow>0.:
		m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=glow
	return m

static func mesh(parent:Node3D,shape:Mesh,mat:Material,position_value:Vector3=Vector3.ZERO)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=shape;node.material_override=mat;node.position=position_value
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.layers=2
	parent.add_child(node);return node

static func box(size_value:Vector3)->BoxMesh:
	var shape:=BoxMesh.new();shape.size=size_value;return shape

static func sphere(radius:float)->SphereMesh:
	var shape:=SphereMesh.new();shape.radius=radius;shape.height=radius*2.;shape.radial_segments=16;shape.rings=8;return shape

static func ring(inner:float,outer:float)->TorusMesh:
	var shape:=TorusMesh.new();shape.inner_radius=inner;shape.outer_radius=outer;shape.rings=24;shape.ring_segments=6;return shape

static func cylinder(radius:float,height:float,tip:bool=false)->CylinderMesh:
	var shape:=CylinderMesh.new();shape.bottom_radius=radius;shape.top_radius=0. if tip else radius;shape.height=height;shape.radial_segments=12;return shape

func warp_wake_mesh()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A handful of curved threads peel away from the hull into a long wake.
	# One shared mesh and one draw per warping craft, without a translucent shell.
	for strand in range(12):
		var angle:=TAU*strand/12.
		for segment in range(24):
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(0,1),Vector2(1,0),Vector2(1,1)]:
				var t:float=(segment+corner.y)/24.
				var a:=angle+sin(t*2.5+angle)*.16
				var spread:=1.+t*t*1.6
				var center:=Vector3(cos(a)*4.9*spread,sin(a)*1.8*spread+.6,-1.-t*(32.+strand%3*6.))
				var across:=Vector3(-sin(a),cos(a),0.)
				surface.set_uv(Vector2(corner.x,t));surface.set_color(Color(strand/12.,0.,0.))
				surface.set_normal(Vector3.UP)
				surface.add_vertex(center+across*(corner.x-.5)*(.45+t*.6))
	return surface.commit()

func configure(state:RefCounted)->void:
	race=state
	steel=material(Color("283b50"));mint=material(Color("59ffda"),1.8)
	flame=material(Color("ffac42"),3.);laser_material=material(Color("ff385e"),2.8)
	bump_material=ShaderMaterial.new();bump_material.shader=load("res://src/plasma.gdshader")
	bump_material.set_shader_parameter("jet_tint",Vector3(1.,.35,.06))
	cores=MultiMesh.new();cores.transform_format=MultiMesh.TRANSFORM_3D;cores.mesh=box(Vector3.ONE*3.5)
	cores.instance_count=race.weapons.pickups.size()
	var batch:=MultiMeshInstance3D.new();batch.multimesh=cores;batch.material_override=mint
	batch.layers=2;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(batch)
	var hoop:=ring(3.8,4.15)
	var wake_shape:=warp_wake_mesh()
	for pickup in race.weapons.pickups:
		var base:=mesh(self,hoop,mint)
		pickup_bases.append(base)
		base.transform=pickup.pose;base.position-=pickup.pose.basis.y*3.
	for p in race.racers:
		var thrusters:=Node3D.new();add_child(thrusters);bump_jets.append(thrusters)
		for end in [-1.,1.]:
			var nozzle:=Vector3(4.,.1,end*2.)
			mesh(thrusters,sphere(.32),material(Color("fff2cb"),4.),nozzle)
			for angle in [0.,PI*.5]:
				var ribbon:=QuadMesh.new();ribbon.size=Vector2(1.6,6.)
				var jet:=mesh(thrusters,ribbon,bump_material,nozzle+Vector3.RIGHT*3.)
				jet.basis=Basis(Vector3.RIGHT,angle)*Basis(Vector3.BACK,PI*.5)
		var collect_mat:=ShaderMaterial.new();collect_mat.shader=load("res://src/pickup_flash.gdshader")
		pickup_echoes.append(mesh(self,ring(.88,1.),collect_mat))
		pickup_halos.append(mesh(self,ring(.91,1.),collect_mat))
		var flash:=OmniLight3D.new();flash.light_color=Color("b4ffac");flash.omni_range=20.
		flash.shadow_enabled=false;flash.light_energy=0.;flash.omni_attenuation=1.6
		add_child(flash);pickup_lights.append(flash)
		var pulse_mat:=ShaderMaterial.new();pulse_mat.shader=load("res://src/emp.gdshader")
		var pulse_shape:=sphere(1.);pulse_shape.radial_segments=64;pulse_shape.rings=32
		emp_fields.append(mesh(self,pulse_shape,pulse_mat))
		emp_rings.append(mesh(self,ring(.991,1.),material(Color("6fcaff"),2.5)))
		var arc_mat:=ShaderMaterial.new();arc_mat.shader=load("res://src/emp_sparks.gdshader")
		arc_mat.set_shader_parameter("seed",float(p.slot))
		var sparks:=mesh(self,EmpSparks.shape(),arc_mat)
		sparks.name="EmpSurfaceSparks%d"%p.slot
		sparks.extra_cull_margin=.4
		emp_arcs.append(sparks)
		turrets.append(make_turret())
		var rack:=Node3D.new();add_child(rack)
		mesh(rack,box(Vector3(.8,.20,2.9)),steel,Vector3(0,-.34,-.3))
		var stored:=Node3D.new();rack.add_child(stored);missile_hull(stored)
		stored.scale=Vector3.ONE*.42
		mounts.append({"missile":rack,"warp":make_coil(true),"emp":make_coil(false),"bomb":make_bomb(),"railgun":make_railgun()})
		var impact:=Impact.new();add_child(impact);impacts.append(impact)
		var wake_material:=ShaderMaterial.new();wake_material.shader=load("res://src/warp_wake.gdshader")
		warp_wakes.append(mesh(self,wake_shape,wake_material))
		var lens_material:=ShaderMaterial.new();lens_material.shader=load("res://src/warp_refraction.gdshader")
		lens_material.render_priority=-30
		var lens:=mesh(self,QuadMesh.new(),lens_material)
		lens.custom_aabb=AABB(Vector3(-15.,-15.,-15.),Vector3.ONE*30.)
		warp_lenses.append(lens)
	for i in range(32): tracers.append(mesh(self,cylinder(1.,1.),material(Color("fff0c2"),5.)))
	for i in range(12): rail_effects.append(make_rail_effect())
	for i in range(24):
		var blast:=Blast.new();add_child(blast);explosions.append(blast);blast_lights.append(blast.flash)
	update()

func make_railgun()->Node3D:
	var gun:=Node3D.new();add_child(gun)
	mesh(gun,box(Vector3(1.3,.65,1.7)),steel,Vector3(0,0,-.5))
	var cyan:=material(Color("4cdbff"),2.)
	for side in [-1.,1.]:
		mesh(gun,box(Vector3(.25,.42,4.3)),steel,Vector3(side*.48,.16,1.4))
		mesh(gun,box(Vector3(.08,.12,3.8)),cyan,Vector3(side*.33,.4,1.5))
		for z in [-.7,-.15,.4]: mesh(gun,box(Vector3(.15,.8,.17)),cyan,Vector3(side*.7,.05,z))
	# A compact adapter raises the firing rails clear of the new cockpit canopy.
	for child in gun.get_children(): child.position.y+=.32
	mesh(gun,box(Vector3(.72,.6,1.1)),steel,Vector3(0,-.02,-.5))
	return gun

func make_rail_effect()->Node3D:
	var effect:=Node3D.new();add_child(effect)
	var beam_mat:=ShaderMaterial.new();beam_mat.shader=load("res://src/rail_beam.gdshader")
	var core_mat:=beam_mat.duplicate() as ShaderMaterial;core_mat.set_shader_parameter("core",true)
	effect.set_meta("core",mesh(effect,cylinder(1.,1.),core_mat))
	effect.set_meta("halo",mesh(effect,cylinder(1.,1.),beam_mat))
	var rings:Array[MeshInstance3D]=[]
	for i in range(5): rings.append(mesh(effect,ring(.93,1.),beam_mat))
	effect.set_meta("rings",rings)
	var flash_mat:=ShaderMaterial.new();flash_mat.shader=load("res://src/rail_flash.gdshader")
	var flash_shape:=QuadMesh.new();flash_shape.size=Vector2(8.,8.)
	effect.set_meta("muzzle",mesh(effect,flash_shape,flash_mat))
	effect.set_meta("hit",mesh(effect,flash_shape,flash_mat))
	for name_value in ["muzzle_light","hit_light"]:
		var light:=OmniLight3D.new();light.light_color=Color("68dfff");light.omni_range=22.;light.shadow_enabled=false
		effect.add_child(light);effect.set_meta(name_value,light)
	effect.visible=false
	return effect

func update_rails()->void:
	for i in range(rail_effects.size()):
		var effect:=rail_effects[i];effect.visible=i<race.weapons.rail_shots.size()
		if not effect.visible: continue
		var shot:Dictionary=race.weapons.rail_shots[i]
		var age:float=Weapons.Railgun.LIFE-shot.life
		var strength:=pow(clampf(shot.life/Weapons.Railgun.LIFE,0.,1.),2.)
		var core:MeshInstance3D=effect.get_meta("core")
		var halo:MeshInstance3D=effect.get_meta("halo")
		line(core,shot.from,shot.to,.07+.06*strength)
		line(halo,shot.from,shot.to,.40+age*.9)
		core.material_override.set_shader_parameter("power",strength)
		halo.material_override.set_shader_parameter("power",strength*.85)
		var rings:Array=effect.get_meta("rings")
		for j in range(rings.size()):
			var radius:float=(.7+age*7.)*(1.-j*.1)
			var position_value:Vector3=shot.from.lerp(shot.to,minf(.98,.025+j*.12+age*.8))
			rings[j].transform=Transform3D(shot.basis*Basis(Vector3.RIGHT,PI*.5).scaled(Vector3.ONE*radius),position_value)
		var muzzle:MeshInstance3D=effect.get_meta("muzzle");muzzle.position=shot.from;muzzle.scale=Vector3.ONE*(.25+strength*.7)
		muzzle.material_override.set_shader_parameter("power",strength)
		var hit:MeshInstance3D=effect.get_meta("hit");hit.visible=shot.contact;hit.position=shot.to;hit.scale=Vector3.ONE*(.3+strength*1.2)
		var light:OmniLight3D=effect.get_meta("muzzle_light");light.position=shot.from;light.light_energy=strength*7.
		light=effect.get_meta("hit_light");light.position=shot.to;light.visible=shot.contact;light.light_energy=strength*9.

func make_bomb()->Node3D:
	var payload:=Node3D.new();add_child(payload)
	var body:=mesh(payload,cylinder(.72,3.1),steel)
	body.rotation.x=PI*.5
	mesh(payload,sphere(.72),steel,Vector3(0,0,1.5))
	var stripe:=mesh(payload,cylinder(.75,.42),material(Color("efa83d")),Vector3(0,0,.85));stripe.rotation.x=PI*.5
	for angle in [0.,PI*.5]:
		var fin:=mesh(payload,box(Vector3(2.5,.12,1.15)),steel,Vector3(0,0,-1.45));fin.rotation.z=angle
	var wings:=Node3D.new();payload.add_child(wings);payload.set_meta("glide_wings",wings)
	for side in [-1.,1.]:
		var wing:=mesh(wings,box(Vector3(3.4,.13,1.05)),steel,Vector3(side*2.,.12,-.2))
		wing.rotation.y=side*.24
		mesh(wing,box(Vector3(.12,.15,.6)),material(Color("efb45a"),1.4),Vector3(side*1.55,0,0))
	wings.scale.x=.22
	mesh(payload,sphere(.16),flame,Vector3(0,.73,.8))
	var motor:=Node3D.new();payload.add_child(motor);payload.set_meta("glide_motor",motor)
	motor.position.z=-2.05;motor.visible=false
	mesh(motor,sphere(.30),material(Color("fff0d8"),7.))
	var glow:=ShaderMaterial.new();glow.shader=load("res://src/engine_glow.gdshader")
	glow.set_shader_parameter("jet_tint",Vector3(1.,.5,.16))
	var glow_quad:=QuadMesh.new();glow_quad.size=Vector2.ONE*2.8
	mesh(motor,glow_quad,glow)
	for angle in [0.,PI*.5]:
		var ribbon:=QuadMesh.new();ribbon.size=Vector2(1.05,4.5)
		var plume:=mesh(motor,ribbon,bump_material,Vector3(0,0,-2.25))
		plume.basis=Basis(Vector3.BACK,angle)*Basis(Vector3.RIGHT,PI*.5)
	return payload

static func line(node:MeshInstance3D,from:Vector3,to:Vector3,width:float)->void:
	var direction:=to-from
	if direction.length_squared()<.001: node.visible=false;return
	var length:=direction.length();direction/=length
	var right:=direction.cross(Vector3.UP).normalized()
	if right.length_squared()<.1: right=Vector3.RIGHT
	node.transform=Transform3D(Basis(right,direction,right.cross(direction)).scaled_local(Vector3(width,length,width)),(from+to)*.5)
	node.visible=true

static func sentry_cylinder(radius:float,height:float)->CylinderMesh:
	var shape:=cylinder(radius,height);shape.radial_segments=8;shape.rings=1;return shape

static func sentry_ring(inner:float,outer:float)->TorusMesh:
	var shape:=ring(inner,outer);shape.rings=12;shape.ring_segments=3;return shape

static func sentry_bulb(radius:float)->SphereMesh:
	var shape:=sphere(radius);shape.radial_segments=8;shape.rings=3;return shape

func make_turret()->Node3D:
	var root:=Node3D.new();add_child(root)
	# The weapon socket rails sit below the old plate: a short adapter physically
	# joins the shoe to the turret instead of leaving the whole gun suspended.
	mesh(root,box(Vector3(.88,.34,1.1)),steel,Vector3(0,-.22,-.1))
	mesh(root,box(Vector3(1.6,.25,1.7)),steel)
	mesh(root,sentry_cylinder(.68,.6),steel,Vector3(0,.3,0))
	mesh(root,sentry_ring(.57,.69),mint,Vector3(0,.58,0))
	var head:=Node3D.new();root.add_child(head);head.position=Weapons.SENTRY_PIVOT;root.set_meta("head",head)
	var armor:=material(Color("8394a6"));armor.cull_mode=BaseMaterial3D.CULL_DISABLED
	var housing:=Ship.loft(head,"ArmoredHead",[Vector3(-.8,.48,.6),Vector3(-.5,.8,.85),Vector3(.45,.7,.65),Vector3(.75,.5,.45)],armor,Vector3.ZERO,true)
	housing.layers=2;housing.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sentry_details(root,head)
	mesh(head,sentry_bulb(.18),mint,Vector3(0,.18,.7))
	mesh(head,sentry_cylinder(.2,.12),steel,Vector3(0,.53,-.35))
	var status_led:=mesh(head,sentry_bulb(.14),material(Color("b5fff0"),3.),Vector3(0,.63,-.35))
	root.set_meta("status_led",status_led)
	var barrels:=Node3D.new();head.add_child(barrels);root.set_meta("barrels",barrels)
	for index in range(6):
		var angle:=TAU*index/6.
		var offset:=Vector3(cos(angle)*.31,sin(angle)*.31,0.)
		var barrel:=mesh(barrels,sentry_cylinder(.105,2.2),steel,offset+Vector3(0,0,1.5));barrel.rotation.x=PI*.5
		var collar:=mesh(barrels,sentry_cylinder(.14,.25),steel,offset+Vector3(0,0,2.45));collar.rotation.x=PI*.5
	var clamp_ring:=mesh(barrels,sentry_ring(.38,.49),steel,Vector3(0,0,2.1));clamp_ring.rotation.x=PI*.5
	var flash_mat:=ShaderMaterial.new();flash_mat.shader=load("res://src/sentry_flash.gdshader")
	var quad:=QuadMesh.new();quad.size=Vector2.ONE*2.4
	var flash:=mesh(head,quad,flash_mat,Vector3(0,0,2.7));flash.visible=false;root.set_meta("muzzle",flash)
	var light:=OmniLight3D.new();light.position=flash.position;light.light_color=Color("ffdc9b")
	light.omni_range=7.;light.light_energy=2.5;light.shadow_enabled=false;light.visible=false
	head.add_child(light);root.set_meta("muzzle_light",light)
	Ship.Design.batch_details(root)
	for node in root.find_children("*","MeshInstance3D",true,false):
		node.layers=2;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	return root

func sentry_details(turret:Node3D,head:Node3D)->void:
	var details:=Node3D.new();details.name="DriveAndFeeder";head.add_child(details)
	var gunmetal:=material(Color("43515a"));gunmetal.metallic=.8
	var black:=material(Color("20262b"));black.metallic=.15;black.roughness=.62
	var edge:=material(Color("7f8d91"));edge.metallic=.85
	var copper:=material(Color("92724c"));copper.metallic=.8
	# Left: a finned electric drive with an exposed rear shaft and protective hoop.
	var motor:=mesh(details,sentry_cylinder(.34,1.32),gunmetal,Vector3(-.97,.02,-.22));motor.rotation.x=PI*.5
	mesh(details,box(Vector3(.42,.36,.64)),gunmetal,Vector3(-.66,-.13,-.10))
	for z in [-.70,-.38,-.06,.26]:
		var fin:=mesh(details,sentry_cylinder(.39,.065),edge,Vector3(-.97,.02,z));fin.rotation.x=PI*.5
	var cover:=mesh(details,sentry_cylinder(.30,.10),black,Vector3(-.97,.02,-.92));cover.rotation.x=PI*.5
	var hoop:=mesh(details,sentry_ring(.24,.30),copper,Vector3(-.97,.02,-.99));hoop.rotation.x=PI*.5
	var axle:=mesh(details,sentry_cylinder(.10,.18),gunmetal,Vector3(-.97,.02,-1.));axle.rotation.x=PI*.5
	var rotor:=Node3D.new();rotor.name="BarrelDriveRotor";rotor.position=Vector3(-.97,.02,-1.025);details.add_child(rotor)
	turret.set_meta("drive_rotor",rotor)
	var hub:=mesh(rotor,sentry_cylinder(.09,.05),copper);hub.rotation.x=PI*.5
	for angle in [0.,TAU/3.,2.*TAU/3.]:
		var spoke:=mesh(rotor,box(Vector3(.065,.40,.04)),edge);spoke.rotation.z=angle
	# Right: a black ammunition cassette and ribbed feed chute entering the breech.
	# A closed magazine casing replaces the thin loft shell. Its inset cover
	# overlaps the solid roof; there are no freestanding straps or overhangs.
	var cassette:=mesh(details,box(Vector3(.68,.88,1.22)),black,Vector3(1.02,.06,-.04));cassette.name="AmmoCassette"
	mesh(details,box(Vector3(.40,.045,.88)),gunmetal,Vector3(1.02,.495,-.04))
	mesh(details,box(Vector3(.32,.27,.62)),gunmetal,Vector3(.72,-.06,-.05))
	var path:=[Vector3(1.02,.06,-.65),Vector3(1.03,.06,-.85),Vector3(.98,.08,-1.08),Vector3(.80,.10,-1.23),Vector3(.56,.10,-1.25),Vector3(.37,.10,-1.09),Vector3(.34,.10,-.82)]
	for i in range(path.size()-1):
		var a:Vector3=path[i];var b:Vector3=path[i+1]
		var link:=mesh(details,box(Vector3(.27,.24,a.distance_to(b)+.035)),black,(a+b)*.5)
		link.basis=Basis.looking_at((b-a).normalized(),Vector3.UP,true)
		var rib:=mesh(details,box(Vector3(.29,.27,.04)),gunmetal,a)
		rib.basis=link.basis
	# Rear service plate stays readable between the asymmetric side modules.
	mesh(details,box(Vector3(.82,.37,.09)),black,Vector3(0,.035,-.815))
	for y in [-.08,.02,.12]: mesh(details,box(Vector3(.40,.03,.045)),edge,Vector3(-.10,y,-.875))
	# Tiny bolts were subpixel geometry. Keep the readable service grille instead.
	# Repeated ribs and rings share draws; the rotor remains independent.
	Ship.Design.batch_details(details)
	for node in details.find_children("*","MeshInstance3D",true,false):
		node.layers=2;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func make_coil(warp:bool)->Node3D:
	var root:=Node3D.new();add_child(root)
	mesh(root,box(Vector3(1.5,.35,2.2)),steel)
	var ink:=material(Color("ac7aff") if warp else Color("72cfff"),1.3)
	var core:=mesh(root,sphere(.55),ink,Vector3(0,.6,0));root.set_meta("core",core)
	for i in range(3):
		if warp:
			var coil:=mesh(root,ring(.68,.83),steel,Vector3(0,.65,(i-1)*.66));coil.rotation.x=PI*.5
			mesh(coil,ring(.58,.64),ink)
		else:
			mesh(root,ring(.55,.76),steel,Vector3(0,.32+i*.3,0))
	for side in [-1.,1.]: mesh(root,box(Vector3(.16,.75,1.8)),steel,Vector3(side*.67,.4,0))
	return root

func missile_hull(root:Node3D)->void:
	# Broad faceted radome, flush body and slim swept surfaces, inspired by the
	# reference's compact modern cruise missile rather than a cone-tipped rocket.
	var hull:=material(Color("b9c1b5"));hull.metallic=.24;hull.roughness=.47
	var radome:=material(Color("68736a"));radome.metallic=.18;radome.roughness=.5
	Ship.loft(root,"MissileBody",[Vector3(-4.,.63,1.1),Vector3(-3.3,.95,1.55),Vector3(2.6,.95,1.55),Vector3(3.1,.85,1.4)],hull,Vector3.ZERO,true)
	Ship.loft(root,"FacetedNose",[Vector3(3.08,.85,1.4),Vector3(4.35,.67,1.06),Vector3(5.9,.05,.10)],radome,Vector3.ZERO,true)
	for side in [-1.,1.]:
		var wing:=Ship.loft(root,"CruiseWing",[Vector3(-1.7,1.35,.08),Vector3(-1.2,1.45,.10),Vector3(.45,.1,.06)],radome,Vector3(side*1.85,-.28,-.1),true)
		wing.rotation.z=side*-.07
		var tail:=Ship.loft(root,"CantedTail",[Vector3(-.65,.9,.09),Vector3(.1,.85,.1),Vector3(1.05,.03,.04)],radome,Vector3(side*.9,.4,-3.15),true)
		tail.rotation.z=side*.65
		mesh(root,box(Vector3(.025,.10,2.7)),steel,Vector3(side*.94,.13,.65))
		mesh(root,box(Vector3(.027,.10,.32)),hull,Vector3(side*.95,.13,.2))
	mesh(root,box(Vector3(.5,.04,.45)),steel,Vector3(0,1.13,-1.9))
	mesh(root,box(Vector3(.5,.04,.45)),steel,Vector3(0,1.13,.9))
	var nozzle:=mesh(root,cylinder(.50,.12),material(Color("080d17")),Vector3(0,0,-4.08));nozzle.rotation.x=PI*.5
	var rim:=mesh(root,ring(.48,.66),steel,Vector3(0,0,-4.15));rim.rotation.x=PI*.5

static func missile_trail_mesh()->ArrayMesh:
	if trail_shape!=null: return trail_shape
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(47):
		for uv in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(0,1),Vector2(1,0),Vector2(1,1)]:
			surface.set_uv(Vector2(uv.x,(i+uv.y)/47.));surface.set_normal(Vector3.UP);surface.add_vertex(Vector3(uv.x,0,i+uv.y))
	trail_shape=surface.commit();return trail_shape

func make_missile()->Node3D:
	var root:=Node3D.new();add_child(root);missile_hull(root)
	var trail_material:=ShaderMaterial.new();trail_material.shader=load("res://src/missile_trail.gdshader")
	trail_material.set_shader_parameter("daylight",race.track.biome=="forest")
	var trail:=mesh(self,missile_trail_mesh(),trail_material);root.set_meta("trail",trail)
	root.scale=Vector3.ONE*.42
	var engine:=Node3D.new();root.add_child(engine);root.set_meta("engine",engine)
	engine.position.z=-4.2
	mesh(engine,sphere(.9),material(Color("fff5dc"),12.))
	var glow_material:=ShaderMaterial.new();glow_material.shader=load("res://src/engine_glow.gdshader")
	glow_material.set_shader_parameter("jet_tint",Vector3(1.,.43,.10))
	var glow_quad:=QuadMesh.new();glow_quad.size=Vector2.ONE*5.
	mesh(engine,glow_quad,glow_material,Vector3(0,0,-.3));root.set_meta("motor_glow",glow_material)
	var flare_material:=ShaderMaterial.new();flare_material.shader=load("res://src/jet_flare.gdshader")
	flare_material.set_shader_parameter("jet_tint",Vector3(1.,.43,.10));flare_material.set_shader_parameter("boost_amount",1.)
	flare_material.render_priority=2
	var flare_quad:=QuadMesh.new();flare_quad.size=Vector2(16.,4.8)
	var flare:=mesh(engine,flare_quad,flare_material,Vector3(0,0,-.5))
	flare.custom_aabb=AABB(Vector3.ONE*-9.,Vector3.ONE*18.);root.set_meta("motor_flare",flare_material)
	var light:=OmniLight3D.new();light.light_color=Color("ffb460");light.omni_range=32.
	light.shadow_enabled=false;light.light_bake_mode=Light3D.BAKE_DISABLED;light.position.z=-4.4
	root.add_child(light);root.set_meta("motor_light",light)
	for angle in [0.,PI*.5]:
		var ribbon:=QuadMesh.new();ribbon.size=Vector2(3.,10.)
		var plume:=mesh(engine,ribbon,bump_material,Vector3(0,0,-5.))
		plume.basis=Basis(Vector3.BACK,angle)*Basis(Vector3.RIGHT,PI*.5)
	var beam_material:=ShaderMaterial.new();beam_material.shader=load("res://src/missile_laser.gdshader")
	var beam:=mesh(self,QuadMesh.new(),beam_material);root.set_meta("laser",beam)
	var contact_material:=ShaderMaterial.new();contact_material.shader=load("res://src/missile_contact.gdshader")
	var contact_quad:=QuadMesh.new();contact_quad.size=Vector2.ONE*2.8
	root.set_meta("contact",mesh(self,contact_quad,contact_material))
	var contact_light:=OmniLight3D.new();contact_light.omni_range=5.5;contact_light.shadow_enabled=false
	contact_light.light_color=Color("fff4ed");contact_light.light_bake_mode=Light3D.BAKE_DISABLED
	add_child(contact_light);root.set_meta("contact_light",contact_light)
	return root

func update()->void:
	# Consume events once per presented frame, not once per physics tick. All
	# split-screen cameras see the same shot; no tracer survives the next frame.
	var frame_id:=Engine.get_process_frames()
	if frame_id!=shot_frame:
		shot_frame=frame_id
		presented_shots=race.weapons.shots.duplicate()
		race.weapons.shots.clear()
	var time:float=race.vfx_clock
	bump_material.set_shader_parameter("race_time",time)
	for i in range(emp_fields.size()):
		emp_fields[i].visible=i<race.weapons.pulses.size()
		emp_rings[i].visible=i<race.weapons.pulses.size()
		if i<race.weapons.pulses.size():
			var pulse:Dictionary=race.weapons.pulses[i]
			var radius:float=maxf(.1,pulse.radius)
			emp_fields[i].transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*radius),pulse.frame.origin)
			emp_fields[i].material_override.set_shader_parameter("age",pulse.age)
			emp_rings[i].transform=pulse.frame*Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*radius),Vector3.ZERO)
			emp_rings[i].visible=pulse.age<.7
	for i in range(race.weapons.pickups.size()):
		var pickup:Dictionary=race.weapons.pickups[i]
		var frame:Transform3D=pickup.pose
		frame.origin+=frame.basis.y*sin(time*2.+i)*.6
		frame.basis=frame.basis*Basis(Vector3.UP,time*.8+i)*Basis(Vector3.FORWARD,PI*.25)
		var reveal:float=pickup.reveal if pickup.cooldown<=0. else 0.
		frame.basis=frame.basis.scaled(Vector3.ONE*reveal)
		cores.set_instance_transform(i,frame)
		pickup_bases[i].visible=pickup.cooldown<=0.
		pickup_bases[i].scale=Vector3.ONE*maxf(.001,reveal)
	var active:Dictionary={}
	for m in race.weapons.missiles:
		var tail_fade:float=clampf(m.fade/1.1,0.,1.) if m.get("disabled",false) else 1.
		active[m.id]=true
		if not missile_nodes.has(m.id): missile_nodes[m.id]=make_missile()
		var node:Node3D=missile_nodes[m.id]
		var ignition:=smoothstep(.18,.65,m.age)
		var motor_power:float=ignition*(.95+.05*sin(time*71.+m.id)) if not m.get("disabled",false) else 0.
		node.get_meta("engine").visible=not m.get("disabled",false) and ignition>.01
		node.get_meta("engine").scale=Vector3(lerpf(.4,1.,ignition),lerpf(.4,1.,ignition),lerpf(.35,1.,ignition))
		node.get_meta("motor_light").light_energy=motor_power*8.
		node.get_meta("motor_glow").set_shader_parameter("power",motor_power*4.)
		node.get_meta("motor_flare").set_shader_parameter("power",motor_power*2.2)
		node.position=m.position
		if m.velocity.length_squared()>.01:
			var forward:Vector3=m.velocity.normalized()
			var up:Vector3=race.track.sample(m.distance).frame.y
			if absf(forward.dot(up))>.98: up=Vector3.UP if absf(forward.y)<.98 else Vector3.RIGHT
			node.basis=m.launch_basis.slerp(Basis.looking_at(forward,up,true),smoothstep(.12,.65,m.age)).scaled(Vector3.ONE*.42)
		var trail:MeshInstance3D=node.get_meta("trail")
		trail.visible=m.trail.size()>1
		if trail.visible:
			var points:=PackedVector3Array();points.resize(48)
			var bounds:=AABB(m.position,Vector3.ZERO)
			for j in range(48):
				points[j]=m.trail[mini(j,m.trail.size()-1)]
				bounds=bounds.expand(points[j])
			if not m.get("disabled",false): points[0]=node.transform*Vector3(0,0,-4.2)
			trail.custom_aabb=bounds.grow(10.)
			trail.material_override.set_shader_parameter("points",points)
			trail.material_override.set_shader_parameter("point_count",m.trail.size())
			trail.material_override.set_shader_parameter("race_time",time)
			trail.material_override.set_shader_parameter("opacity",tail_fade)
		var beam:MeshInstance3D=node.get_meta("laser")
		var warning:=Weapons.laser_strength(race,m)
		beam.visible=warning>0.
		var contact:MeshInstance3D=node.get_meta("contact")
		var contact_light:OmniLight3D=node.get_meta("contact_light")
		contact.visible=beam.visible;contact_light.visible=beam.visible
		if warning>0.:
			var intensity:=warning
			var target_frame:=Weapons.pose(race,race.racers[m.target])
			# Contact sits on the exposed canopy instead of inside the hull.
			var destination:=target_frame*Vector3(0.,1.45,-.6)
			contact.position=destination
			contact.material_override.set_shader_parameter("strength",intensity)
			contact_light.position=destination+target_frame.basis.y*.3
			contact_light.light_energy=intensity*4.5
			var beam_material:ShaderMaterial=beam.material_override
			beam_material.set_shader_parameter("strength",intensity)
			beam_material.set_shader_parameter("beam_radius",lerpf(.012,.03,intensity))
			beam_material.set_shader_parameter("head_world",m.position)
			beam_material.set_shader_parameter("tail_world",destination)
			# Vertex shader faces each camera; CPU bounds still span the real segment.
			beam.custom_aabb=AABB(m.position,Vector3.ZERO).expand(destination).grow(1.)
	var live_bombs:Dictionary={}
	for bomb in race.weapons.bombs:
		live_bombs[bomb.id]=true
		if not bomb_nodes.has(bomb.id): bomb_nodes[bomb.id]=make_bomb()
		var payload:Node3D=bomb_nodes[bomb.id]
		payload.position=bomb.position
		payload.get_meta("glide_wings").scale.x=lerpf(.22,1.,smoothstep(.05,.38,bomb.age))
		var motor:Node3D=payload.get_meta("glide_motor")
		var power:=Weapons.DiveBomb.motor_power(bomb.age)
		motor.visible=power>.001;motor.scale=Vector3.ONE*maxf(.001,power)
		if bomb.velocity.length_squared()>.01:
			var direction:Vector3=bomb.velocity.normalized()
			payload.basis=Basis.looking_at(direction,Vector3.UP if absf(direction.y)<.98 else Vector3.RIGHT,true)
	for id in bomb_nodes.keys():
		if not live_bombs.has(id): bomb_nodes[id].queue_free();bomb_nodes.erase(id)
	for id in missile_nodes.keys():
		if active.has(id): continue
		var trail:MeshInstance3D=missile_nodes[id].get_meta("trail")
		if trail.visible: fading_trails.append({"mesh":trail,"until":time+.65})
		else: trail.queue_free()
		missile_nodes[id].get_meta("laser").queue_free()
		missile_nodes[id].get_meta("contact").queue_free()
		missile_nodes[id].get_meta("contact_light").queue_free()
		missile_nodes[id].queue_free();missile_nodes.erase(id)
	for tail in fading_trails.duplicate():
		if time>=tail.until:
			tail.mesh.queue_free();fading_trails.erase(tail)
		else:
			tail.mesh.material_override.set_shader_parameter("opacity",(tail.until-time)/.65)
			tail.mesh.material_override.set_shader_parameter("race_time",time)
	while fading_trails.size()>24:
		var oldest:Dictionary=fading_trails.pop_front();oldest.mesh.queue_free()
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		var frame:=Weapons.pose(race,p)
		# Active hardware owns the single socket; queued inventory stays in the HUD.
		var mounted:=mounted_kind(p)
		for kind in mounts[i]:
			var attachment:Node3D=mounts[i][kind]
			attachment.visible=not p.crashed and mounted==kind
			attachment.transform=frame*Transform3D(Basis.IDENTITY,Ship.Design.SOCKET)
			if kind in ["warp","emp"]:
				var core:MeshInstance3D=attachment.get_meta("core")
				core.scale=Vector3.ONE*(1.+sin(time*(10. if p.warp_time>0. else 2.5))*.08)
				if kind=="warp":
					core.material_override.albedo_color=Color("ac7aff").lerp(Color("c2f6ff"),p.warp_fx)
					core.material_override.emission=core.material_override.albedo_color
					core.material_override.emission_energy_multiplier=1.3+p.warp_fx*1.8
		var side_jets:=bump_jets[i]
		side_jets.visible=p.bump_time>0. and not p.crashed and not p.airborne
		var pulse:=maxf(.05,sin(clampf(1.-p.bump_time/.24,0.,1.)*PI))
		side_jets.transform=frame*Transform3D(Basis(Vector3.UP,PI if p.bump_side<0. else 0.).scaled_local(Vector3(1.,pulse,pulse)),Vector3.ZERO)
		var flash:float=clampf(p.pickup_fx/.45,0.,1.)
		pickup_echoes[i].visible=flash>0.
		pickup_halos[i].visible=flash>0. and not p.crashed
		var pickup_radius:=4.+(1.-flash)*9.
		pickup_echoes[i].transform=p.pickup_pose*Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*pickup_radius),Vector3.ZERO)
		pickup_halos[i].transform=frame.scaled_local(Vector3(5.+(1.-flash)*2.,.6,6.+(1.-flash)*2.))
		pickup_halos[i].material_override.set_shader_parameter("strength",flash)
		var pickup_tint:=Color("ffd369") if p.pickup_energy else Color("b4ffac")
		pickup_halos[i].material_override.set_shader_parameter("tint",Vector3(pickup_tint.r,pickup_tint.g,pickup_tint.b))
		pickup_lights[i].light_color=pickup_tint
		pickup_lights[i].visible=flash>0. and not p.crashed
		pickup_lights[i].position=frame.origin+frame.basis.y*3.
		pickup_lights[i].light_energy=flash*3.
		var arcs:=emp_arcs[i]
		arcs.visible=p.emp_time>0. and not p.crashed
		arcs.transform=frame
		arcs.material_override.set_shader_parameter("age",maxf(0.,Weapons.EMP_DURATION-p.emp_time))
		arcs.material_override.set_shader_parameter("strength",smoothstep(0.,.55,p.emp_time))
		var turret:=turrets[i];turret.visible=mounted=="drone" and not p.crashed
		turret.transform=frame*Transform3D(Basis.IDENTITY,Weapons.SENTRY_MOUNT)
		var head:Node3D=turret.get_meta("head")
		var sentry_active:bool=p.drone_time>0.
		if sentry_active and p.drone_target>=0:
			head.basis=frame.basis.inverse()*Weapons.sentry_basis(race,p)
		elif sentry_active:
			# Search across the forward arc; tracking takes over once a rival is found.
			head.basis=Basis(Vector3.UP,sin(time*1.8+p.slot*.7)*.72)*Basis(Vector3.RIGHT,sin(time*1.1)*.06)
		else:
			head.basis=Basis(Vector3.RIGHT,.14) # Carried, barrels lowered and unarmed.
		var status_led:MeshInstance3D=turret.get_meta("status_led")
		var led_on:bool=sentry_active and fposmod(time+p.slot*.11,1.2)<.18
		var led_color:=Color("b5fff0") if led_on else Color("122522")
		status_led.material_override.albedo_color=led_color
		status_led.material_override.emission=led_color
		status_led.material_override.emission_energy_multiplier=3. if led_on else 0.
		var firing:=false
		for shot in presented_shots:
			if shot.get("owner",-1)==i: firing=true;break
		var barrels:Node3D=turret.get_meta("barrels")
		barrels.position.z=-.07 if firing else 0.
		barrels.rotation.z=time*(38. if p.drone_target>=0 else 9.) if sentry_active else 0.
		turret.get_meta("drive_rotor").rotation.z=-barrels.rotation.z*1.8
		turret.get_meta("muzzle").visible=firing
		turret.get_meta("muzzle_light").visible=firing

		impacts[i].show_hit(p)
		var wake:=warp_wakes[i]
		wake.visible=p.warp_fx>.01 and not p.crashed
		wake.transform=frame
		wake.material_override.set_shader_parameter("strength",p.warp_fx)
		wake.material_override.set_shader_parameter("race_time",time)
		var lens:=warp_lenses[i]
		lens.visible=wake.visible;lens.transform=frame
		lens.material_override.set_shader_parameter("strength",p.warp_fx)
		lens.material_override.set_shader_parameter("race_time",time)
	update_rails()
	for i in range(tracers.size()):
		tracers[i].visible=i<presented_shots.size()
		if tracers[i].visible:
			var shot:Dictionary=presented_shots[i];line(tracers[i],shot.from,shot.to,.025)
	for i in range(explosions.size()):
		explosions[i].visible=i<race.weapons.bursts.size()
		if explosions[i].visible:
			var burst:Dictionary=race.weapons.bursts[i]
			var age:float=float(burst.get("duration",Weapons.MISSILE_BLAST_LIFE))-burst.life
			explosions[i].show_blast(burst.id,burst.position,age,float(burst.get("size",14.)),1. if race.track.biome=="forest" else .75)

static func mounted_kind(p:Dictionary)->String:
	if p.drone_time>0.: return "drone"
	if p.warp_time>0. or p.warp_fx>.01: return "warp"
	var finished_mounts:Array=p.get("victory_mounts",[])
	if "drone" in finished_mounts: return "drone"
	if "warp" in finished_mounts: return "warp"
	if not finished_mounts.is_empty(): return str(finished_mounts[0])
	return p.weapon
