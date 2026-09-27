extends Node3D
const Weapons=preload("res://src/weapons.gd")
const Blast=preload("res://src/blast_vfx.gd")
const Ship=preload("res://src/ship.gd")
var race:RefCounted
var cores:MultiMesh
var battery_batches:Array[MultiMesh]=[]
var missile_nodes:Dictionary={}
var turrets:Array[Node3D]=[]
var mounts:Array[Dictionary]=[]
var shields:Array[MeshInstance3D]=[]
var warp_wakes:Array[MeshInstance3D]=[]
var warp_lenses:Array[MeshInstance3D]=[]
var tracers:Array[MeshInstance3D]=[]
var explosions:Array[Node3D]=[]
var blast_lights:Array[OmniLight3D]=[]
var smoke:MultiMesh
var smoke_count:=0
var emp_fields:Array[MeshInstance3D]=[]
var emp_rings:Array[MeshInstance3D]=[]
var emp_arcs:Array[MeshInstance3D]=[]
var dishes:Array[Node3D]=[]
var radio_waves:Array[Array]=[]
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

func battery_batch(parts:Array,mat:Material)->void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts: surface.append_from(box(part[0]),0,Transform3D(Basis.IDENTITY,part[1]))
	var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.mesh=surface.commit()
	instances.instance_count=race.weapons.batteries.size();battery_batches.append(instances)
	var batch:=MultiMeshInstance3D.new();batch.multimesh=instances;batch.material_override=mat
	batch.layers=2;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(batch)

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
	# Three instanced materials for every battery: housing, charge bars, white +.
	battery_batch([[Vector3(2.8,3.9,1.8),Vector3.ZERO],[Vector3(1.1,.45,1.),Vector3(0,2.15,0)]],material(Color("263342")))
	var cells:Array=[];var symbols:Array=[]
	for side in [-1.,1.]:
		for y in [-1.1,-.4,.3]: cells.append([Vector3(2.,.44,.1),Vector3(0,y,side*.95)])
		symbols.append([Vector3(.9,.19,.12),Vector3(0,1.2,side*.96)])
		symbols.append([Vector3(.19,.9,.12),Vector3(0,1.2,side*.96)])
	battery_batch(cells,material(Color("ffbf38"),1.7))
	battery_batch(symbols,material(Color("fff4c9"),2.))
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
		dishes.append(make_dish())
		var waves:Array=[]
		for j in range(3):
			var wave_mat:=ShaderMaterial.new();wave_mat.shader=load("res://src/jammer_wave.gdshader")
			waves.append(mesh(self,ring(.972,1.),wave_mat))
		radio_waves.append(waves)
		var pulse_mat:=ShaderMaterial.new();pulse_mat.shader=load("res://src/emp.gdshader")
		var pulse_shape:=sphere(1.);pulse_shape.radial_segments=64;pulse_shape.rings=32
		emp_fields.append(mesh(self,pulse_shape,pulse_mat))
		emp_rings.append(mesh(self,ring(.991,1.),material(Color("6fcaff"),2.5)))
		var arc_mat:=pulse_mat.duplicate() as ShaderMaterial
		arc_mat.set_shader_parameter("shutdown",true)
		emp_arcs.append(mesh(self,sphere(1.),arc_mat))
		turrets.append(make_turret())
		var rack:=Node3D.new();add_child(rack)
		mesh(rack,box(Vector3(.8,.35,4.6)),steel,Vector3(0,-.65,-.3))
		var stored:=Node3D.new();rack.add_child(stored);missile_hull(stored)
		stored.scale=Vector3.ONE*.62
		mounts.append({"missile":rack,"warp":make_coil(true),"emp":make_coil(false)})
		var shield_mat:=ShaderMaterial.new();shield_mat.shader=load("res://src/weapon_shield.gdshader")
		var shield:=mesh(self,sphere(6.3),shield_mat);shields.append(shield)
		var wake_material:=ShaderMaterial.new();wake_material.shader=load("res://src/warp_wake.gdshader")
		warp_wakes.append(mesh(self,wake_shape,wake_material))
		var lens_material:=ShaderMaterial.new();lens_material.shader=load("res://src/warp_refraction.gdshader")
		lens_material.render_priority=-30
		var lens:=mesh(self,QuadMesh.new(),lens_material)
		lens.custom_aabb=AABB(Vector3(-15.,-15.,-15.),Vector3.ONE*30.)
		warp_lenses.append(lens)
	for i in range(32): tracers.append(mesh(self,cylinder(1.,1.),flame))
	for i in range(24):
		var blast:=Blast.new();add_child(blast);explosions.append(blast);blast_lights.append(blast.flash)
	smoke=MultiMesh.new();smoke.transform_format=MultiMesh.TRANSFORM_3D;smoke.use_custom_data=true
	var puff:=QuadMesh.new();puff.size=Vector2.ONE*2.;smoke.mesh=puff;smoke.instance_count=384
	var smoke_node:=MultiMeshInstance3D.new();smoke_node.multimesh=smoke
	var smoke_mat:=ShaderMaterial.new();smoke_mat.shader=load("res://src/missile_smoke.gdshader");smoke_node.material_override=smoke_mat
	smoke_node.layers=2;smoke_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(smoke_node)
	update()

func make_dish()->Node3D:
	var dish:=Node3D.new();add_child(dish)
	mesh(dish,box(Vector3(1.2,.18,1.3)),steel)
	mesh(dish,cylinder(.16,1.4),steel,Vector3(0,.7,0))
	mesh(dish,sphere(.3),steel,Vector3(0,1.3,0))
	var bowl:=SurfaceTool.new();bowl.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(6):
		for slice in range(32):
			var corners:Array[Vector3]=[]
			for corner in [Vector2(row,slice),Vector2(row+1,slice),Vector2(row+1,slice+1),Vector2(row,slice+1)]:
				var r:float=corner.x/6.*1.65;var angle:float=corner.y/32.*TAU
				corners.append(Vector3(cos(angle)*r,sin(angle)*r+1.5,r*r*.22))
			for index in [0,1,2,0,2,3]: bowl.add_vertex(corners[index])
	bowl.generate_normals()
	var alloy:=material(Color("b4c2c9"));alloy.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh(dish,bowl.commit(),alloy)
	var rim:=mesh(dish,ring(1.6,1.68),material(Color("ffaa51"),1.7),Vector3(0,1.5,.6))
	rim.rotation.x=PI*.5
	var feed:=Vector3(0,1.5,1.65)
	for angle in [0.,TAU/3.,TAU*2./3.]:
		var support:=mesh(dish,cylinder(1.,1.),steel)
		line(support,Vector3(cos(angle)*1.55,1.5+sin(angle)*1.55,.53),feed,.055)
	mesh(dish,sphere(.2),material(Color("ffcb7f"),3.),feed)
	return dish

static func line(node:MeshInstance3D,from:Vector3,to:Vector3,width:float)->void:
	var direction:=to-from
	if direction.length_squared()<.001: node.visible=false;return
	var length:=direction.length();direction/=length
	var right:=direction.cross(Vector3.UP).normalized()
	if right.length_squared()<.1: right=Vector3.RIGHT
	node.transform=Transform3D(Basis(right,direction,right.cross(direction)).scaled_local(Vector3(width,length,width)),(from+to)*.5)
	node.visible=true

func make_turret()->Node3D:
	var root:=Node3D.new();add_child(root)
	mesh(root,box(Vector3(1.6,.25,1.7)),steel)
	mesh(root,cylinder(.68,.6),steel,Vector3(0,.3,0))
	mesh(root,ring(.57,.69),mint,Vector3(0,.58,0))
	var head:=Node3D.new();root.add_child(head);head.position=Weapons.SENTRY_PIVOT;root.set_meta("head",head)
	var armor:=material(Color("8394a6"));armor.cull_mode=BaseMaterial3D.CULL_DISABLED
	var housing:=Ship.loft(head,"ArmoredHead",[Vector3(-.8,.48,.6),Vector3(-.5,.8,.85),Vector3(.45,.7,.65),Vector3(.75,.5,.45)],armor,Vector3.ZERO,true)
	housing.layers=2;housing.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh(head,sphere(.18),mint,Vector3(0,.18,.7))
	var barrels:=Node3D.new();head.add_child(barrels);root.set_meta("barrels",barrels)
	for side in [-1.,1.]:
		var barrel:=mesh(barrels,cylinder(.17,2.2),steel,Vector3(side*.48,-.06,1.5));barrel.rotation.x=PI*.5
		var collar:=mesh(barrels,cylinder(.24,.4),steel,Vector3(side*.48,-.06,2.3));collar.rotation.x=PI*.5
		var flash:=mesh(barrels,sphere(.23),flame,Vector3(side*.48,-.06,2.65));flash.name="MuzzleL" if side<0. else "MuzzleR"
	return root

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
	var hull:=material(Color("c4c9ce"));hull.metallic=.7
	var body:=mesh(root,cylinder(1.25,8.),hull);body.rotation.x=PI*.5
	var nose:=mesh(root,cylinder(1.25,3.,true),laser_material,Vector3(0,0,5.5));nose.rotation.x=PI*.5
	var band:=mesh(root,cylinder(1.28,.5),flame,Vector3(0,0,2.8));band.rotation.x=PI*.5
	var nozzle:=mesh(root,cylinder(.9,.12),material(Color("080d17")),Vector3(0,0,-4.08));nozzle.rotation.x=PI*.5
	var rim:=mesh(root,ring(.82,1.04),steel,Vector3(0,0,-4.15));rim.rotation.x=PI*.5
	for angle in [0.,PI*.5]:
		var fin:=mesh(root,box(Vector3(4.8 if angle==0. else 2.8,.2,2.5)),steel,Vector3(0,0,-2.7));fin.rotation.z=angle

func make_missile()->Node3D:
	var root:=Node3D.new();add_child(root);missile_hull(root)
	root.scale=Vector3.ONE*.62
	var engine:=Node3D.new();root.add_child(engine);root.set_meta("engine",engine)
	engine.position.z=-4.2
	mesh(engine,sphere(.9),material(Color("fff5c9"),4.))
	var light:=OmniLight3D.new();light.light_color=Color("ffb460");light.omni_range=18.
	light.shadow_enabled=false;light.light_bake_mode=Light3D.BAKE_DISABLED;light.position.z=-3.
	root.add_child(light);root.set_meta("motor_light",light)
	for angle in [0.,PI*.5]:
		var ribbon:=QuadMesh.new();ribbon.size=Vector2(3.,10.)
		var plume:=mesh(engine,ribbon,bump_material,Vector3(0,0,-5.))
		plume.basis=Basis(Vector3.BACK,angle)*Basis(Vector3.RIGHT,PI*.5)
	var beam_material:=ShaderMaterial.new();beam_material.shader=load("res://src/missile_laser.gdshader")
	var beam:=mesh(self,QuadMesh.new(),beam_material);root.set_meta("laser",beam)
	var contact_material:=ShaderMaterial.new();contact_material.shader=load("res://src/missile_contact.gdshader")
	var contact_quad:=QuadMesh.new();contact_quad.size=Vector2.ONE*2.2
	root.set_meta("contact",mesh(self,contact_quad,contact_material))
	var contact_light:=OmniLight3D.new();contact_light.omni_range=4.;contact_light.shadow_enabled=false
	contact_light.light_color=Color("fff4ed");contact_light.light_bake_mode=Light3D.BAKE_DISABLED
	add_child(contact_light);root.set_meta("contact_light",contact_light)
	return root

func puff(position_value:Vector3,radius:float,opacity:float,heat:float,seed_value:float)->void:
	if smoke_count>=smoke.instance_count: return
	smoke.set_instance_transform(smoke_count,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*radius),position_value))
	smoke.set_instance_custom_data(smoke_count,Color(opacity,heat,seed_value,1.));smoke_count+=1

func update()->void:
	var time:float=race.vfx_clock
	smoke_count=0
	bump_material.set_shader_parameter("race_time",time)
	for i in range(race.weapons.batteries.size()):
		var battery:Dictionary=race.weapons.batteries[i]
		var frame:Transform3D=battery.pose
		frame.origin+=frame.basis.y*sin(time*2.3+i)*.45
		frame.basis=frame.basis*Basis(Vector3.UP,sin(time*.9+i)*.3)
		frame.basis=frame.basis.scaled(Vector3.ONE*(1.35 if battery.get("air",false) else 1.)*(battery.reveal if battery.cooldown<=0. else 0.))
		for batch in battery_batches: batch.set_instance_transform(i,frame)
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
		for j in range(m.trail.size()): puff(m.trail[j],1.4+j*.22,(1.-j/16.)*.45*tail_fade,0.,j*1.37)
		active[m.id]=true
		if not missile_nodes.has(m.id): missile_nodes[m.id]=make_missile()
		var node:Node3D=missile_nodes[m.id]
		var ignition:=smoothstep(.18,.65,m.age)
		node.get_meta("engine").visible=not m.get("disabled",false) and ignition>.01
		node.get_meta("engine").scale=Vector3(lerpf(.4,1.,ignition),lerpf(.4,1.,ignition),lerpf(.35,1.,ignition))
		node.get_meta("motor_light").light_energy=ignition*3. if not m.get("disabled",false) else 0.
		node.position=m.position
		if m.velocity.length_squared()>.01:
			var forward:Vector3=m.velocity.normalized()
			var up:Vector3=race.track.sample(m.distance).frame.y
			if absf(forward.dot(up))>.98: up=Vector3.UP if absf(forward.y)<.98 else Vector3.RIGHT
			node.basis=m.launch_basis.slerp(Basis.looking_at(forward,up,true),smoothstep(.12,.65,m.age)).scaled(Vector3.ONE*.62)
		var beam:MeshInstance3D=node.get_meta("laser")
		var warning:=1.-clampf(Weapons.missile_eta(race,m)/2.,0.,1.)
		beam.visible=warning>0.
		var contact:MeshInstance3D=node.get_meta("contact")
		var contact_light:OmniLight3D=node.get_meta("contact_light")
		contact.visible=beam.visible;contact_light.visible=beam.visible
		if warning>0.:
			var intensity:=smoothstep(0.,1.,warning)
			var target_frame:=Weapons.pose(race,race.racers[m.target])
			# Contact sits on the exposed canopy instead of inside the hull.
			var destination:=target_frame*Vector3(0.,1.45,-.6)
			contact.position=destination
			contact.material_override.set_shader_parameter("strength",intensity)
			contact_light.position=destination+target_frame.basis.y*.3
			contact_light.light_energy=intensity*2.5
			var beam_material:ShaderMaterial=beam.material_override
			beam_material.set_shader_parameter("strength",intensity)
			beam_material.set_shader_parameter("beam_radius",lerpf(.012,.03,intensity))
			beam_material.set_shader_parameter("head_world",m.position)
			beam_material.set_shader_parameter("tail_world",destination)
			# Vertex shader faces each camera; CPU bounds still span the real segment.
			beam.custom_aabb=AABB(m.position,Vector3.ZERO).expand(destination).grow(1.)
	for id in missile_nodes.keys():
		if active.has(id): continue
		missile_nodes[id].get_meta("laser").queue_free()
		missile_nodes[id].get_meta("contact").queue_free()
		missile_nodes[id].get_meta("contact_light").queue_free()
		missile_nodes[id].queue_free();missile_nodes.erase(id)
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		var frame:=Weapons.pose(race,p)
		for kind in mounts[i]:
			var attachment:Node3D=mounts[i][kind]
			attachment.visible=not p.crashed and (p.weapon==kind or (kind=="warp" and p.warp_fx>.01))
			var socket:Vector3=Weapons.MISSILE_MOUNT if kind=="missile" else (Vector3(-2.45,.65,1.35) if kind=="warp" else Vector3(0.,.55,2.1))
			attachment.transform=frame*Transform3D(Basis.IDENTITY,socket)
			if kind!="missile":
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
		var dish:=dishes[i]
		dish.visible=(p.weapon=="jammer" or p.jammer_deploy>.01) and not p.crashed
		var deployment:=maxf(.3 if p.weapon=="jammer" else .01,p.jammer_deploy)
		dish.transform=frame*Transform3D(Basis.IDENTITY.scaled(Vector3(.65,deployment*.65,.65)),Vector3(-2.45,.65,-1.4))
		for j in range(3):
			var wave:MeshInstance3D=radio_waves[i][j]
			wave.visible=p.jammer_time>0. and p.emp_time<=0. and not p.crashed
			var phase:=fposmod(time*.9+j/3.,1.)
			var ahead:=5.+phase*Weapons.JAMMER_RANGE
			var radius:=ahead*tan(deg_to_rad(Weapons.JAMMER_HALF_ANGLE))
			wave.transform=frame*Transform3D(Basis(Vector3.RIGHT,PI*.5).scaled(Vector3.ONE*radius),Vector3(0,0,ahead))
			var envelope:=smoothstep(0.,.10,phase)*pow(1.-phase,2.2)*smoothstep(0.,1.,p.jammer_time)
			wave.material_override.set_shader_parameter("power",envelope*p.jammer_deploy)
			wave.material_override.set_shader_parameter("phase",phase)
			wave.material_override.set_shader_parameter("race_time",time)
		var arcs:=emp_arcs[i]
		arcs.visible=p.emp_time>0. and not p.crashed
		arcs.transform=frame.scaled_local(Vector3(5.3,2.3,5.8))
		arcs.material_override.set_shader_parameter("age",time+p.slot)
		arcs.material_override.set_shader_parameter("strength",minf(1.,p.emp_time*4.))
		var turret:=turrets[i];turret.visible=(p.weapon=="drone" or p.drone_time>0.) and not p.crashed
		turret.transform=frame*Transform3D(Basis.IDENTITY,Weapons.SENTRY_MOUNT)
		var head:Node3D=turret.get_meta("head")
		head.basis=frame.basis.inverse()*Weapons.sentry_basis(race,p)
		var recoil:=clampf((p.drone_cooldown-.30)/.10,0.,1.) if p.drone_target>=0 and p.drone_time>0. else 0.
		var barrels:Node3D=turret.get_meta("barrels");barrels.position.z=-recoil*.22
		for barrel in barrels.get_children():
			if str(barrel.name).begins_with("Muzzle"): barrel.visible=recoil>.5
		var shield:=shields[i]
		shield.visible=p.shield_hit>0. and not p.crashed
		shield.transform=frame.scaled_local(Vector3(1.,.6,1.))
		shield.material_override.set_shader_parameter("strength",p.shield_hit/.28)
		shield.material_override.set_shader_parameter("race_time",time)
		var wake:=warp_wakes[i]
		wake.visible=p.warp_fx>.01 and not p.crashed
		wake.transform=frame
		wake.material_override.set_shader_parameter("strength",p.warp_fx)
		wake.material_override.set_shader_parameter("race_time",time)
		var lens:=warp_lenses[i]
		lens.visible=wake.visible;lens.transform=frame
		lens.material_override.set_shader_parameter("strength",p.warp_fx)
		lens.material_override.set_shader_parameter("race_time",time)
	for i in range(tracers.size()):
		tracers[i].visible=i<race.weapons.shots.size()
		if tracers[i].visible:
			var shot:Dictionary=race.weapons.shots[i];line(tracers[i],shot.from,shot.to,.055)
	for i in range(explosions.size()):
		explosions[i].visible=i<race.weapons.bursts.size()
		if explosions[i].visible:
			var burst:Dictionary=race.weapons.bursts[i]
			var age:float=Weapons.MISSILE_BLAST_LIFE-burst.life
			explosions[i].show_blast(burst.id,burst.position,age,14.,1. if race.track.biome=="forest" else .75)
	smoke.visible_instance_count=smoke_count
