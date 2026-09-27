extends RefCounted
## Beveled hull, swept aerofoils, recessed cockpit and additive engine plumes.
static var discharge_mesh:ArrayMesh
const WAKE_SPAN:=20.

static func boost_mesh()->ArrayMesh:
	if discharge_mesh!=null: return discharge_mesh
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Six main bolts, each with one fork. The shader animates this fixed topology.
	for branch in range(12):
		for segment in range(8):
			for corner in [[0,0],[1,0],[0,1],[0,1],[1,0],[1,1]]:
				surface.set_color(Color(float(branch)/12.,0.,0.))
				surface.set_uv(Vector2(corner[1],float(segment+corner[0])/8.))
				surface.set_normal(Vector3.UP)
				surface.add_vertex(Vector3(corner[1],0.,float(segment+corner[0])))
	discharge_mesh=surface.commit()
	return discharge_mesh

static func boost_surge(time:float,slot:int,side:int)->float:
	var phase:=time+slot*.713+side*.379
	# Unequal frequencies avoid a metronomic blink; no gameplay RNG is consumed.
	return pow(.5+.5*sin(phase*23.7+sin(phase*9.1)*2.4),4.)*.65+pow(.5+.5*sin(phase*41.3),8.)*.35
static func metal(color:Color,roughness:float=.3)->StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.metallic=.65
	material.roughness=roughness
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	return material

static func loft(parent:Node3D,name_value:String,sections:Array,material:Material,offset:Vector3=Vector3.ZERO,seal:bool=false)->MeshInstance3D:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cross_section:=[Vector2(-1,-.05),Vector2(-.96,.10),Vector2(-.71,.67),Vector2(-.60,.72),Vector2(.60,.72),Vector2(.71,.67),Vector2(.96,.10),Vector2(1,-.05),Vector2(.65,-.5),Vector2(-.65,-.5)]
	for i in range(sections.size()-1):
		for j in range(cross_section.size()):
			for cell in [[i,j],[i+1,j],[i,(j+1)%cross_section.size()],[i,(j+1)%cross_section.size()],[i+1,j],[i+1,(j+1)%cross_section.size()]]:
				var section:Vector3=sections[cell[0]] # z, half width, height
				var corner:Vector2=cross_section[cell[1]]
				surface.set_uv(Vector2(float(cell[1])/cross_section.size(),section.x*.2))
				surface.add_vertex(Vector3(corner.x*section.y,corner.y*section.z,section.x))
	if seal:
		for index in [0,sections.size()-1]:
			var section:Vector3=sections[index]
			for j in range(cross_section.size()):
				var a:Vector2=cross_section[j]
				var b:Vector2=cross_section[(j+1)%cross_section.size()]
				for point in [Vector3(0,0,section.x),Vector3(a.x*section.y,a.y*section.z,section.x),Vector3(b.x*section.y,b.y*section.z,section.x)]:
					surface.add_vertex(point)
	surface.generate_normals()
	var mesh:=MeshInstance3D.new()
	mesh.name=name_value
	mesh.mesh=surface.commit()
	mesh.material_override=material
	mesh.position=offset
	parent.add_child(mesh)
	return mesh

static func build(tint:Color)->Node3D:
	var root:=Node3D.new()
	var jet_tint:=Color("67cfff").lerp(tint,.65)
	root.set_meta("jet_tint",jet_tint)
	var paint:=ShaderMaterial.new()
	paint.shader=load("res://src/ship.gdshader")
	paint.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
	loft(root,"Body",[Vector3(-3.4,.1,.1),Vector3(-2.7,1.5,.8),Vector3(.2,1.65,1.2),Vector3(2.8,.8,.4),Vector3(5,.025,.03)],paint)
	var alloy:=metal(Color("233045"),.24)
	var control_edge:=metal(Color("93acb8"),.28)
	var glass:=metal(Color("101e35"),.12)
	glass.metallic=.85
	loft(root,"Canopy",[Vector3(-1.7,.1,.1),Vector3(-.6,.78,.9),Vector3(.8,.52,.8),Vector3(1.9,.01,.01)],glass,Vector3(0,.75,0))
	for side in [-1,1]:
		loft(root,"Nacelle%d"%side,[Vector3(-3.7,.7,.6),Vector3(-2,.9,.7),Vector3(1.4,.63,.55),Vector3(3.2,.05,.08)],alloy,Vector3(side*2.45,-.15,0))
		# The fixed wing ends at the hinge; it must not cover the moving elevon.
		loft(root,"Wing%d"%side,[Vector3(-1.24,1.15,.18),Vector3(.4,.08,.1)],paint,Vector3(side*3.4,0,0))
		# Hinged elevons on the rear of each wing; inside the existing hull envelope.
		var wing:=Node3D.new()
		wing.name="WingControlL" if side<0 else "WingControlR"
		wing.position=Vector3(side*3.4,.12,-1.45)
		root.add_child(wing)
		loft(wing,"Elevon",[Vector3(-1.0,.45,.13),Vector3(-.6,1.0,.16),Vector3(.1,.95,.14),Vector3(.2,.03,.03)],paint)
		loft(wing,"FlapEdge",[Vector3(-1.01,.43,.045),Vector3(-.94,.49,.045)],control_edge)
		var fin:=Node3D.new()
		fin.name="RudderL" if side<0 else "RudderR"
		fin.position=Vector3(side*1.05,.5,-2.35)
		root.add_child(fin)
		loft(fin,"TailFin",[Vector3(-1,.02,.15),Vector3(-.65,.09,1.55),Vector3(.4,.08,.3),Vector3(.55,.02,.05)],paint)
		loft(fin,"RudderEdge",[Vector3(-1.015,.025,.18),Vector3(-.66,.105,1.58),Vector3(-.55,.095,1.43)],control_edge)
		var strip:=StandardMaterial3D.new()
		strip.albedo_color=tint
		strip.emission_enabled=true
		strip.emission=tint
		strip.emission_energy_multiplier=.7
		loft(root,"Light%d"%side,[Vector3(-2.8,.10,.10),Vector3(1.5,.10,.10),Vector3(2.2,.025,.02)],strip,Vector3(side*2.45,.4,0))
		# Machined nozzle rims make the bright exhaust socket part of the hull.
		var collar:=MeshInstance3D.new()
		collar.name="Nozzle%d"%side
		var ring:=TorusMesh.new()
		ring.inner_radius=.38
		ring.outer_radius=.62
		ring.rings=16
		ring.ring_segments=8
		collar.mesh=ring
		collar.material_override=metal(Color("8193a6"),.2)
		collar.position=Vector3(side*2.45,-.12,-3.68)
		collar.rotation.x=PI*.5
		root.add_child(collar)
		var plume:=MeshInstance3D.new()
		plume.name="ExhaustL" if side<0 else "ExhaustR"
		var jet:=SurfaceTool.new()
		jet.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Crossed tapered ribbons remain visible from behind, above and through rolls.
		var sections:=[Vector2(0,.65),Vector2(.12,1),Vector2(.45,.55),Vector2(1,.015)]
		for plane in range(4):
			var axis:=Vector3(cos(plane*PI/4),sin(plane*PI/4),0)
			for i in range(sections.size()-1):
				for corner in [[i,-1],[i+1,-1],[i,1],[i,1],[i+1,-1],[i+1,1]]:
					var point:Vector2=sections[corner[0]]
					jet.set_uv(Vector2((corner[1]+1)*.5,point.x))
					jet.add_vertex(axis*point.y*corner[1]+Vector3(0,0,-point.x))
		jet.generate_normals()
		plume.mesh=jet.commit()
		var plasma:=ShaderMaterial.new()
		plasma.shader=load("res://src/plasma.gdshader")
		plasma.set_shader_parameter("jet_tint",Vector3(jet_tint.r,jet_tint.g,jet_tint.b))
		plume.material_override=plasma
		plume.position=Vector3(side*2.45,-.12,-3.65)
		plume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(plume)
		var arcs:=MeshInstance3D.new();arcs.name="BoostArcs%d"%side
		arcs.mesh=boost_mesh();arcs.position=plume.position
		arcs.custom_aabb=AABB(Vector3(-5.,-5.,-19.),Vector3(10.,10.,20.))
		arcs.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var discharge:=ShaderMaterial.new();discharge.shader=load("res://src/boost_arcs.gdshader")
		discharge.set_shader_parameter("jet_tint",Vector3(jet_tint.r,jet_tint.g,jet_tint.b))
		arcs.material_override=discharge;arcs.visible=false;root.add_child(arcs)
		var reverse:=MeshInstance3D.new()
		reverse.name="Reverse%d"%side
		reverse.mesh=plume.mesh
		reverse.material_override=plasma.duplicate()
		reverse.material_override.set_shader_parameter("braking",1.0)
		reverse.position=Vector3(side*2.45,-.05,2.2)
		reverse.rotation.y=PI
		reverse.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(reverse)
		var airbrake:=Node3D.new()
		airbrake.name="Airbrake%d"%side
		airbrake.position=Vector3(side*2.45,.42,-.4)
		root.add_child(airbrake)
		loft(airbrake,"Door",[Vector3(-1.8,.5,.12),Vector3(-1.5,.64,.12),Vector3(0,.55,.12)],alloy)
		var warning:=metal(Color("ff6b32"))
		warning.emission_enabled=true
		warning.emission=Color("ff4218")
		loft(airbrake,"BrakeLight",[Vector3(-1.72,.48,.04),Vector3(-1.58,.52,.04)],warning,Vector3(0,.1,0))
		var halo:=MeshInstance3D.new()
		halo.name="EngineHalo%d"%side
		var quad:=QuadMesh.new()
		quad.size=Vector2(2.6,2.6)
		halo.mesh=quad
		halo.position=plume.position+Vector3(0,0,-.15)
		halo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var halo_material:=ShaderMaterial.new()
		halo_material.shader=load("res://src/engine_glow.gdshader")
		halo_material.set_shader_parameter("jet_tint",Vector3(jet_tint.r,jet_tint.g,jet_tint.b))
		halo.material_override=halo_material
		root.add_child(halo)
		var flare:=MeshInstance3D.new()
		flare.name="EngineFlare%d"%side
		var optics:=QuadMesh.new();optics.size=Vector2(13.,3.9)
		flare.mesh=optics;flare.position=plume.position+Vector3(0,0,-.3)
		flare.custom_aabb=AABB(Vector3.ONE*-7.,Vector3.ONE*14.)
		flare.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var flare_material:=ShaderMaterial.new();flare_material.shader=load("res://src/jet_flare.gdshader")
		flare_material.set_shader_parameter("jet_tint",Vector3(jet_tint.r,jet_tint.g,jet_tint.b))
		flare_material.render_priority=2;flare.material_override=flare_material
		root.add_child(flare)
		var heat:=MeshInstance3D.new();heat.name="EngineHeat%d"%side
		heat.mesh=QuadMesh.new();heat.position=plume.position+Vector3(0,-.35,-.5)
		heat.custom_aabb=AABB(Vector3(-3.,-3.,-20.),Vector3(6.,6.,21.))
		heat.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var heat_material:=ShaderMaterial.new();heat_material.shader=load("res://src/jet_heat.gdshader")
		heat_material.render_priority=-20;heat.material_override=heat_material
		root.add_child(heat)
		var core:=MeshInstance3D.new()
		core.name="EngineCore%d"%side
		var bulb:=SphereMesh.new()
		bulb.radius=.3
		bulb.height=.6
		bulb.radial_segments=8
		bulb.rings=4
		core.mesh=bulb
		var glow:=StandardMaterial3D.new()
		glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color=Color("d3ffff")
		glow.emission_enabled=true
		glow.emission=jet_tint.lightened(.45)
		core.material_override=glow
		core.position=plume.position
		core.scale=Vector3(1,.7,.5)
		root.add_child(core)
	# Each nozzle illuminates the hull, road and other racers in the shared world.
	var engine_light:=OmniLight3D.new()
	engine_light.name="EngineLight"
	engine_light.position=Vector3(-2.45,.3,-3.9)
	engine_light.light_color=Color("75cfff")
	engine_light.light_energy=0.0
	engine_light.omni_range=19.0
	engine_light.omni_attenuation=1.6
	engine_light.light_specular=.8
	engine_light.shadow_enabled=false
	engine_light.light_volumetric_fog_energy=.45
	root.add_child(engine_light)
	var right_light:=engine_light.duplicate() as OmniLight3D
	right_light.name="EngineLightR"
	right_light.position.x=2.45
	root.add_child(right_light)
	var wake:=MultiMeshInstance3D.new()
	wake.name="EngineWake"
	wake.custom_aabb=AABB(Vector3(-6.,-3.,-70.),Vector3(12.,6.,72.))
	var particles:=MultiMesh.new()
	particles.transform_format=MultiMesh.TRANSFORM_3D
	particles.use_colors=true
	particles.mesh=QuadMesh.new()
	particles.instance_count=20
	wake.multimesh=particles
	var trail:=ShaderMaterial.new()
	trail.shader=load("res://src/exhaust_particle.gdshader")
	wake.material_override=trail
	wake.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(wake)
	return root

static func set_jet_tint(root:Node3D,tint:Color)->void:
	var color:=Color("67cfff").lerp(tint,.65)
	root.set_meta("jet_tint",color)
	for side in [-1,1]:
		root.get_node("ExhaustL" if side<0 else "ExhaustR").material_override.set_shader_parameter("jet_tint",Vector3(color.r,color.g,color.b))
		root.get_node("EngineHalo%d"%side).material_override.set_shader_parameter("jet_tint",Vector3(color.r,color.g,color.b))
		root.get_node("EngineFlare%d"%side).material_override.set_shader_parameter("jet_tint",Vector3(color.r,color.g,color.b))
		root.get_node("BoostArcs%d"%side).material_override.set_shader_parameter("jet_tint",Vector3(color.r,color.g,color.b))
		root.get_node("EngineCore%d"%side).material_override.emission=color.lightened(.45)

static func animate_controls(root:Node3D,p:Dictionary)->void:
	if p.crashed: return
	for side in [-1,1]:
		var wing:Node3D=root.get_node("WingControlL" if side<0 else "WingControlR")
		# Right-stick strafe/roll drives ailerons; left-stick turn drives the rudder.
		wing.rotation.x=clampf(-p.input_pitch*.55-p.input_strafe*side*.5+p.input_brake*.6,-.85,.95)
		wing.rotation.z=-p.input_strafe*.16
		root.get_node("Airbrake%d"%side).rotation.x=p.brake_vfx*1.15
		var rudder:Node3D=root.get_node("RudderL" if side<0 else "RudderR")
		# More readable small deflections, without changing the steering physics.
		rudder.rotation.y=signf(p.input_steer)*pow(absf(p.input_steer),.72)*.7

static func animate_effects(root:Node3D,p:Dictionary,time:float,countdown:float)->void:
	var alive:bool=p.recovery<=0 and (not p.finished or p.has("victory_pose")) and not p.crashed
	var power:float=p.engine_power if alive else 0.0
	var burning:bool=(p.boost>0 or p.on_pad) and p.braking<.05 and not p.airborne and p.thrust>0 and alive
	var drive:float=smoothstep(0,125,p.acceleration) if countdown<=0 else 0.0
	var engine_light:OmniLight3D=root.get_node("EngineLight")
	engine_light.visible=alive and power>.015
	engine_light.light_energy=power*(2.6+(5.4 if burning else 0.0))
	var jet_tint:Color=root.get_meta("jet_tint",Color("75cfff"))
	engine_light.light_color=jet_tint.lightened(.25) if burning else jet_tint
	engine_light.omni_range=28.0 if burning else 19.0
	var right_light:OmniLight3D=root.get_node("EngineLightR")
	right_light.visible=engine_light.visible
	right_light.light_energy=engine_light.light_energy
	right_light.light_color=engine_light.light_color
	right_light.omni_range=engine_light.omni_range
	var length:=.65+power*1.4+drive*power*4.0+(5.5 if burning else 0.0)
	for side in [-1,1]:
		var surge:=boost_surge(time,p.slot,side) if burning else 0.
		var nozzle_light:OmniLight3D=engine_light if side<0 else right_light
		nozzle_light.light_energy+=power*surge*4.
		var exhaust:MeshInstance3D=root.get_node("ExhaustL" if side<0 else "ExhaustR")
		exhaust.scale=Vector3(.8+surge*.2 if burning else .6,.65+surge*.15 if burning else .45,length*(.9+surge*.35 if burning else 1.))
		exhaust.material_override.set_shader_parameter("race_time",time+p.slot*.71+side*.379)
		exhaust.material_override.set_shader_parameter("power",power)
		exhaust.material_override.set_shader_parameter("boost_amount",1.0 if burning else 0.0)
		var core:MeshInstance3D=root.get_node("EngineCore%d"%side)
		core.material_override.albedo_color=Color("152d42").lerp(Color("eeffff"),power)
		core.material_override.emission_energy_multiplier=power*(8.+surge*5. if burning else 3.)
		core.scale=Vector3(1,.7,.5)*(.75+power*.5)
		var halo:MeshInstance3D=root.get_node("EngineHalo%d"%side)
		halo.scale=Vector3.ONE*(.6+power*.65+(.4+surge*.2 if burning else 0.0))
		halo.material_override.set_shader_parameter("power",power)
		var arcs:MeshInstance3D=root.get_node("BoostArcs%d"%side)
		arcs.visible=burning and power>.015
		arcs.material_override.set_shader_parameter("race_time",time+p.slot*.71+side*.379)
		# One shape per presented frame, even when rendering faster than physics.
		# Paused scenes skip this update, preserving the frozen effect snapshot.
		arcs.material_override.set_shader_parameter("strike_frame",float(Engine.get_process_frames()%4096))
		arcs.material_override.set_shader_parameter("power",power)
		arcs.material_override.set_shader_parameter("surge",surge)
		for effect_name in ["EngineFlare%d"%side,"EngineHeat%d"%side]:
			var effect:MeshInstance3D=root.get_node(effect_name)
			effect.visible=alive and power>.015
			effect.material_override.set_shader_parameter("power",power*(1.+surge*.3))
			effect.material_override.set_shader_parameter("boost_amount",1. if burning else 0.)
		var heat:ShaderMaterial=root.get_node("EngineHeat%d"%side).material_override
		heat.set_shader_parameter("race_time",time+p.slot*.71)
		heat.set_shader_parameter("trail_length",length+5.)
		var reverse:MeshInstance3D=root.get_node("Reverse%d"%side)
		reverse.visible=p.brake_vfx>.01 and alive
		reverse.scale=Vector3(.45,.35,.2+p.brake_vfx*2.8)
		reverse.material_override.set_shader_parameter("power",p.brake_vfx*.9)
		reverse.material_override.set_shader_parameter("race_time",time)
	var wake:MultiMesh=root.get_node("EngineWake").multimesh
	# Positions are local to the moving craft: subtract its forward speed as well
	# as the exhaust ejection speed, so sparks travel backward in world space.
	var vehicle_speed:float=p.air_velocity.length() if p.airborne else absf(p.speed)
	var exhaust_speed:=vehicle_speed+220.+power*160.+(220. if burning else 0.)
	var previous_time:float=root.get_meta("wake_time",time)
	var elapsed:=clampf(time-previous_time,0.,.1)
	var travel:=fposmod(float(root.get_meta("wake_travel",0.))+exhaust_speed*elapsed,WAKE_SPAN)
	root.set_meta("wake_time",time)
	root.set_meta("wake_travel",travel)
	for particle in range(20):
		# Integrate distance instead of multiplying absolute time by changing speed.
		# A fixed wake span prevents throttle changes from teleporting the particles.
		var distance:=fposmod(travel+particle*11.072+p.slot*19.84,WAKE_SPAN)
		var age:=distance/WAKE_SPAN
		var side:=1 if particle%2==0 else -1
		var phase:=particle*2.4
		var position:=Vector3(side*2.45+sin(phase)*age*.3,-.12+cos(phase)*age*.22,-3.8-distance)
		# Overlapping wisps stay attached to the jet and die before reaching the camera.
		var diameter:=lerpf(.24,.36,age)*(1.+.12*sin(phase))
		var size:=Vector3(diameter,diameter,clampf(exhaust_speed*.006,3.,5.4))*(power if countdown<=0 else 0.0)
		wake.set_instance_transform(particle,Transform3D(Basis.IDENTITY.scaled(size),position))
		wake.set_instance_color(particle,Color(jet_tint.r,jet_tint.g,jet_tint.b,pow(1.-age,3.)*power*(.36 if burning else .25)))
