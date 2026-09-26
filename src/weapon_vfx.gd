extends Node3D
const Weapons=preload("res://src/weapons.gd")
var race:RefCounted
var cores:MultiMesh
var missile_nodes:Dictionary={}
var drones:Array[Node3D]=[]
var shields:Array[MeshInstance3D]=[]
var rings:Array[Array]=[]
var tracers:Array[MeshInstance3D]=[]
var explosions:Array[MeshInstance3D]=[]
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

func configure(state:RefCounted)->void:
	race=state
	steel=material(Color("283b50"));mint=material(Color("59ffda"),1.8)
	flame=material(Color("ffac42"),3.);laser_material=material(Color("ff385e"),2.8)
	cores=MultiMesh.new();cores.transform_format=MultiMesh.TRANSFORM_3D;cores.mesh=box(Vector3.ONE*3.5)
	cores.instance_count=race.weapons.pickups.size()
	var batch:=MultiMeshInstance3D.new();batch.multimesh=cores;batch.material_override=mint
	batch.layers=2;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(batch)
	var hoop:=ring(3.8,4.15)
	for pickup in race.weapons.pickups:
		var base:=mesh(self,hoop,mint)
		base.transform=pickup.pose;base.position-=pickup.pose.basis.y*3.
	for p in race.racers:
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
	for i in range(race.weapons.pickups.size()):
		var pickup:Dictionary=race.weapons.pickups[i]
		var frame:Transform3D=pickup.pose
		frame.origin+=frame.basis.y*sin(time*2.+i)*.6
		frame.basis=frame.basis*Basis(Vector3.UP,time*.8+i)*Basis(Vector3.FORWARD,PI*.25)
		cores.set_instance_transform(i,frame)
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
