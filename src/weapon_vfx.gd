extends Node3D
const Weapons=preload("res://src/weapons.gd")
var race:RefCounted
var cores:MultiMesh
var battery_batches:Array[MultiMesh]=[]
var missile_nodes:Dictionary={}
var drones:Array[Node3D]=[]
var shields:Array[MeshInstance3D]=[]
var rings:Array[Array]=[]
var tracers:Array[MeshInstance3D]=[]
var explosions:Array[MeshInstance3D]=[]
var guidance:Array[Node3D]=[]
var guidance_material:ShaderMaterial
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

func configure(state:RefCounted)->void:
	race=state
	steel=material(Color("283b50"));mint=material(Color("59ffda"),1.8)
	flame=material(Color("ffac42"),3.);laser_material=material(Color("ff385e"),2.8)
	guidance_material=ShaderMaterial.new();guidance_material.shader=load("res://src/plasma.gdshader")
	guidance_material.set_shader_parameter("jet_tint",Vector3(.08,.9,.7))
	bump_material=guidance_material.duplicate() as ShaderMaterial
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
			waves.append(mesh(self,ring(.993,1.),wave_mat))
		radio_waves.append(waves)
		var pulse_mat:=ShaderMaterial.new();pulse_mat.shader=load("res://src/emp.gdshader")
		var pulse_shape:=sphere(1.);pulse_shape.radial_segments=64;pulse_shape.rings=32
		emp_fields.append(mesh(self,pulse_shape,pulse_mat))
		emp_rings.append(mesh(self,ring(.991,1.),material(Color("6fcaff"),2.5)))
		var arc_mat:=pulse_mat.duplicate() as ShaderMaterial
		arc_mat.set_shader_parameter("shutdown",true)
		emp_arcs.append(mesh(self,sphere(1.),arc_mat))
		var boosters:=Node3D.new();add_child(boosters);guidance.append(boosters)
		for side in [-1.,1.]:
			for end in [-1.,1.]:
				var nozzle:=Vector3(side*3.4,-.4,end*2.2)
				mesh(boosters,sphere(.35),material(Color("dfffff"),4.),nozzle)
				for angle in [0.,PI*.5]:
					var ribbon:=QuadMesh.new();ribbon.size=Vector2(1.4,4.6)
					var jet:=mesh(boosters,ribbon,guidance_material,nozzle+Vector3.DOWN*2.3)
					jet.rotation.y=angle
		var drone:=Node3D.new();add_child(drone);drones.append(drone)
		mesh(drone,box(Vector3(1.5,.65,2.)),steel)
		mesh(drone,sphere(.35),mint,Vector3(0,.05,1.))
		for side in [-1.,1.]:
			for front in [-1.,1.]:
				var arm:=mesh(drone,box(Vector3(2.3,.16,.22)),steel,Vector3(side*.9,0,front*.8))
				arm.rotation.y=-side*front*.65
				var motor:=mesh(drone,cylinder(.38,.35),steel,Vector3(side*1.9,.12,front*1.5))
				mesh(motor,ring(.58,.69),mint,Vector3(0,.18,0))
				var blade:=mesh(motor,box(Vector3(1.25,.05,.12)),steel,Vector3(0,.22,0));blade.name="Rotor"
		var gun:=mesh(drone,cylinder(.2,1.6),steel,Vector3(0,-.5,1.2));gun.rotation.x=PI*.5
		var shield_mat:=ShaderMaterial.new();shield_mat.shader=load("res://src/weapon_shield.gdshader")
		var shield:=mesh(self,sphere(6.3),shield_mat);shields.append(shield)
		var warp_rings:Array=[]
		for i in range(3):
			var hoop_node:=mesh(self,ring(7.,7.15),material(Color("b478ff"),2.))
			warp_rings.append(hoop_node)
		rings.append(warp_rings)
	for i in range(32): tracers.append(mesh(self,cylinder(1.,1.),flame))
	for i in range(24):
		var impact:=ShaderMaterial.new();impact.shader=load("res://src/weapon_impact.gdshader")
		explosions.append(mesh(self,sphere(1.),impact))
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

func make_missile()->Node3D:
	var root:=Node3D.new();add_child(root)
	var body:=mesh(root,cylinder(.55,3.5),steel);body.rotation.x=PI*.5
	var nose:=mesh(root,cylinder(.55,1.4,true),laser_material,Vector3(0,0,2.2));nose.rotation.x=PI*.5
	for angle in [0.,PI*.5]:
		var fin:=mesh(root,box(Vector3(2.1,.12,.8)),steel,Vector3(0,0,-1.3));fin.rotation.z=angle
	var plume:=mesh(root,cylinder(.42,4.,true),flame,Vector3(0,0,-3.5));plume.rotation.x=-PI*.5
	var beam:=mesh(self,cylinder(1.,1.),laser_material);root.set_meta("laser",beam)
	return root

func update()->void:
	var time:float=race.vfx_clock
	guidance_material.set_shader_parameter("race_time",time)
	bump_material.set_shader_parameter("race_time",time)
	for i in range(race.weapons.batteries.size()):
		var battery:Dictionary=race.weapons.batteries[i]
		var frame:Transform3D=battery.pose
		frame.origin+=frame.basis.y*sin(time*2.3+i)*.45
		frame.basis=frame.basis*Basis(Vector3.UP,sin(time*.9+i)*.3)
		frame.basis=frame.basis.scaled(Vector3.ONE*(battery.reveal if battery.cooldown<=0. else 0.))
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
		active[m.id]=true
		if not missile_nodes.has(m.id): missile_nodes[m.id]=make_missile()
		var node:Node3D=missile_nodes[m.id]
		node.position=m.position
		if m.velocity.length_squared()>.01:
			var forward:Vector3=m.velocity.normalized()
			var up:=Vector3.UP if absf(forward.y)<.98 else Vector3.RIGHT
			node.basis=Basis.looking_at(forward,up,true)
		var beam:MeshInstance3D=node.get_meta("laser")
		if m.evaded: beam.visible=false
		else: line(beam,m.position,Weapons.pose(race,race.racers[m.target]).origin,.085)
	for id in missile_nodes.keys():
		if active.has(id): continue
		missile_nodes[id].get_meta("laser").queue_free()
		missile_nodes[id].queue_free();missile_nodes.erase(id)
	for i in range(race.racers.size()):
		var p:Dictionary=race.racers[i]
		var frame:=Weapons.pose(race,p)
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
		dish.visible=p.jammer_deploy>.01 and not p.crashed
		dish.transform=frame*Transform3D(Basis.IDENTITY.scaled(Vector3(1.,maxf(.01,p.jammer_deploy),1.)),Vector3(0,2.,-1.5))
		for j in range(3):
			var wave:MeshInstance3D=radio_waves[i][j]
			wave.visible=p.jammer_time>0. and p.emp_time<=0. and not p.crashed
			var phase:=fposmod(time*.9+j/3.,1.)
			var ahead:=5.+phase*Weapons.JAMMER_RANGE
			var radius:=ahead*tan(deg_to_rad(Weapons.JAMMER_HALF_ANGLE))
			wave.transform=frame*Transform3D(Basis(Vector3.RIGHT,PI*.5).scaled(Vector3.ONE*radius),Vector3(0,0,ahead))
			wave.material_override.set_shader_parameter("power",(1.-phase)*p.jammer_deploy)
		var arcs:=emp_arcs[i]
		arcs.visible=p.emp_time>0. and not p.crashed
		arcs.transform=frame.scaled_local(Vector3(5.3,2.3,5.8))
		arcs.material_override.set_shader_parameter("age",time+p.slot)
		arcs.material_override.set_shader_parameter("strength",minf(1.,p.emp_time*4.))
		var boosters:=guidance[i]
		boosters.visible=p.landing_fx>0. and not p.crashed
		boosters.transform=frame
		boosters.scale=Vector3(1.,clampf(p.landing_fx/.5,0.,1.)*(1.+sin(time*67.)*.12),1.)
		var drone:=drones[i];drone.visible=p.drone_time>0. and not p.crashed
		drone.transform=Transform3D(frame.basis.scaled(Vector3.ONE*1.35),Weapons.drone_position(race,p))
		if drone.visible:
			for rotor in drone.find_children("Rotor","MeshInstance3D",true,false): rotor.rotation.y=time*75.
			if p.drone_target>=0:
				var target:=Weapons.pose(race,race.racers[p.drone_target]).origin
				if target.distance_squared_to(drone.position)>.1: drone.look_at(target,frame.basis.y,true)
			drone.scale=Vector3.ONE*1.35
		var shield:=shields[i]
		shield.visible=(p.shield_hit>0. or p.warp_fx>.01) and not p.crashed
		shield.transform=frame.scaled_local(Vector3(1.,.6,1.))
		shield.material_override.set_shader_parameter("strength",maxf(p.shield_hit/.28,p.warp_fx*.45))
		shield.material_override.set_shader_parameter("warp",p.warp_fx)
		shield.material_override.set_shader_parameter("race_time",time)
		for j in range(3):
			var hoop:MeshInstance3D=rings[i][j]
			hoop.visible=p.warp_fx>.05 and not p.crashed
			var phase:=fposmod(time*1.7+j/3.,1.)
			hoop.transform=frame*Transform3D(Basis(Vector3.RIGHT,PI*.5).scaled(Vector3.ONE*(.6+phase*1.2)),Vector3(0,0,12.-phase*45.))
	for i in range(tracers.size()):
		tracers[i].visible=i<race.weapons.shots.size()
		if tracers[i].visible:
			var shot:Dictionary=race.weapons.shots[i];line(tracers[i],shot.from,shot.to,.055)
	for i in range(explosions.size()):
		explosions[i].visible=i<race.weapons.bursts.size()
		if explosions[i].visible:
			var burst:Dictionary=race.weapons.bursts[i]
			explosions[i].position=burst.position
			explosions[i].scale=Vector3.ONE*(1.-burst.life/.45)*13.+Vector3.ONE*.5
			explosions[i].material_override.set_shader_parameter("age",1.-burst.life/.45)
