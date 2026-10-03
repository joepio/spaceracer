extends RefCounted
## Beveled hull, swept aerofoils, recessed cockpit and additive engine plumes.
static func metal(color:Color,roughness:float=.3)->StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.metallic=.65
	material.roughness=roughness
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	return material

static func loft(parent:Node3D,name_value:String,sections:Array,material:Material,offset:Vector3=Vector3.ZERO)->MeshInstance3D:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cross_section:=[Vector2(-1,0),Vector2(-.65,.72),Vector2(.65,.72),Vector2(1,0),Vector2(.65,-.5),Vector2(-.65,-.5)]
	for i in range(sections.size()-1):
		for j in range(6):
			for cell in [[i,j],[i+1,j],[i,(j+1)%6],[i,(j+1)%6],[i+1,j],[i+1,(j+1)%6]]:
				var section:Vector3=sections[cell[0]] # z, half width, height
				var corner:Vector2=cross_section[cell[1]]
				surface.set_uv(Vector2(float(cell[1])/6,section.x*.2))
				surface.add_vertex(Vector3(corner.x*section.y,corner.y*section.z,section.x))
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
	var paint:=ShaderMaterial.new()
	paint.shader=load("res://src/ship.gdshader")
	paint.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
	loft(root,"Body",[Vector3(-3.4,.1,.1),Vector3(-2.7,1.5,.8),Vector3(.2,1.65,1.2),Vector3(2.8,.8,.4),Vector3(5,.025,.03)],paint)
	var alloy:=metal(Color("233045"),.24)
	var glass:=metal(Color("101e35"),.12)
	glass.metallic=.85
	loft(root,"Canopy",[Vector3(-1.7,.1,.1),Vector3(-.6,.78,.9),Vector3(.8,.52,.8),Vector3(1.9,.01,.01)],glass,Vector3(0,.75,0))
	for side in [-1,1]:
		loft(root,"Nacelle%d"%side,[Vector3(-3.7,.7,.6),Vector3(-2,.9,.7),Vector3(1.4,.63,.55),Vector3(3.2,.05,.08)],alloy,Vector3(side*2.45,-.15,0))
		loft(root,"Wing%d"%side,[Vector3(-2.3,.05,.04),Vector3(-1.6,1.2,.18),Vector3(.4,.08,.1)],paint,Vector3(side*3.4,0,0))
		# Hinged elevons on the rear of each wing; inside the existing hull envelope.
		var wing:=Node3D.new()
		wing.name="WingControlL" if side<0 else "WingControlR"
		wing.position=Vector3(side*3.4,.12,-1.45)
		root.add_child(wing)
		loft(wing,"Elevon",[Vector3(-1.0,.45,.13),Vector3(-.6,1.0,.16),Vector3(.1,.95,.14),Vector3(.2,.03,.03)],paint)
		loft(wing,"FlapEdge",[Vector3(-1.01,.43,.03),Vector3(-.94,.49,.03)],alloy)
		var fin:=Node3D.new()
		fin.name="RudderL" if side<0 else "RudderR"
		fin.position=Vector3(side*1.05,.5,-2.35)
		root.add_child(fin)
		loft(fin,"TailFin",[Vector3(-1,.02,.15),Vector3(-.65,.09,1.55),Vector3(.4,.08,.3),Vector3(.55,.02,.05)],paint)
		var strip:=StandardMaterial3D.new()
		strip.albedo_color=tint
		strip.emission_enabled=true
		strip.emission=tint
		strip.emission_energy_multiplier=.7
		loft(root,"Light%d"%side,[Vector3(-2.8,.10,.10),Vector3(1.5,.10,.10),Vector3(2.2,.025,.02)],strip,Vector3(side*2.45,.4,0))
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
		plume.material_override=plasma
		plume.position=Vector3(side*2.45,-.12,-3.65)
		plume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(plume)
		var core:=MeshInstance3D.new()
		var bulb:=SphereMesh.new()
		bulb.radius=.3
		bulb.height=.6
		bulb.radial_segments=8
		bulb.rings=4
		core.mesh=bulb
		var glow:=StandardMaterial3D.new()
		glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color=Color("d3ffff")
		core.material_override=glow
		core.position=plume.position
		core.scale=Vector3(1,.7,.5)
		root.add_child(core)
	var wake:=MultiMeshInstance3D.new()
	wake.name="EngineWake"
	var particles:=MultiMesh.new()
	particles.transform_format=MultiMesh.TRANSFORM_3D
	particles.use_colors=true
	particles.mesh=BoxMesh.new()
	particles.instance_count=20
	wake.multimesh=particles
	var trail:=StandardMaterial3D.new()
	trail.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	trail.vertex_color_use_as_albedo=true
	trail.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	trail.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	trail.no_depth_test=false
	wake.material_override=trail
	wake.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(wake)
	return root

static func animate_controls(root:Node3D,p:Dictionary)->void:
	for side in [-1,1]:
		var wing:Node3D=root.get_node("WingControlL" if side<0 else "WingControlR")
		# Pull-back raises trailing edges; differential deflection banks into steering.
		wing.rotation.x=clampf(-p.input_pitch*.55-p.input_steer*side*.5+p.input_brake*.6,-.85,.95)
		wing.rotation.z=-p.input_strafe*.16
		var rudder:Node3D=root.get_node("RudderL" if side<0 else "RudderR")
		rudder.rotation.y=-p.input_strafe*.55-p.input_steer*.18
