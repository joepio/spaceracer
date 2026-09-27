extends RefCounted
## A dense, instanced city; all architecture is validated against the road ribbon.
const Layout=preload("res://src/city_layout.gd")
var layout:RefCounted
var traffic:MultiMesh
var cabins:MultiMesh
var lamps:MultiMesh
var animation_time:=0.0
var local_lights:Array[Light3D]=[]
var reflection_boxes:Array[Dictionary]=[]
var groups:Dictionary={}
var accent:Color
var secondary:Color
var obstacles:RefCounted

static func mat(color:Color,emission:float=0.0)->StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=color
	m.roughness=.45
	m.metallic=.4
	if emission>0:
		m.emission_enabled=true
		m.emission=color
		m.emission_energy_multiplier=emission
	return m

static func batch(parent:Node3D,mesh:Mesh,material:Material,count:int,layer:int=1,dynamic:bool=false)->MultiMesh:
	var data:=MultiMesh.new()
	data.transform_format=MultiMesh.TRANSFORM_3D
	data.use_colors=true
	data.mesh=mesh
	data.instance_count=count
	var renderer:=MultiMeshInstance3D.new()
	renderer.multimesh=data
	renderer.layers=layer
	renderer.set_meta("gi_dynamic",dynamic or layer==2)
	renderer.material_override=material
	renderer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if layer==1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(renderer)
	return data

func part(kind:int,position:Vector3,size:Vector3,color:Color)->void:
	if obstacles: obstacles.add_box(Transform3D(Basis.IDENTITY.scaled(size),position))
	if kind==3:
		kind=0
		color.a=0.0 # solid rooftop equipment shares the architecture draw batch
	var key:=Vector3i(floori(position.x/640),kind,floori(position.z/640))
	if not groups.has(key): groups[key]=[]
	groups[key].append({"transform":Transform3D(Basis.IDENTITY.scaled(size),position),"color":color})

func build(parent:Node3D,race:RefCounted)->void:
	obstacles=race.track.obstacles
	accent=race.track.theme[3]
	secondary=race.track.theme[4]
	layout=Layout.new(race.track)
	for b in layout.buildings:
		var c:Vector3=b.center
		var w:float=b.width
		var d:float=b.depth
		var h:float=b.height
		var tint:Color=b.color
		# Inset podium avoids coplanar faces with full-width lower building volumes.
		part(0,c+Vector3.UP*h*.07,Vector3(w*.98,h*.14,d*.98),tint)
		match b.kind:
			0: # slab with a rooftop communications mast
				part(0,c+Vector3.UP*h*.54,Vector3(w*.78,h*.92,d*.82),tint)
			1: # paired residential towers on a common podium
				for side in [-1,1]: part(0,c+Vector3(side*w*.255,h*.55,0),Vector3(w*.36,h*.9,d*.72),tint)
			2: # three stepped terraces
				for tier in range(3):
					var scale_value:=1-tier*.23
					part(0,c+Vector3.UP*h*(.2+tier*.3),Vector3(w*scale_value,h*.4,d*scale_value),tint)
					part(2,c+Vector3.UP*h*(.4+tier*.3),Vector3(w*scale_value-.5,1.8,d*scale_value-.5),tint)
			3: # octagonal glass tower and inset penthouse
				part(1,c+Vector3.UP*h*.48,Vector3(w*.92,h*.96,d*.92),tint)
				part(1,c+Vector3.UP*h*.98,Vector3(w*.55,h*.12,d*.55),tint)
			4: # stacked offset office volumes
				for tier in range(3):
					part(0,c+Vector3(w*(.12 if tier%2==0 else -.12),h*(.22+tier*.28),0),Vector3(w*.72,h*.42,d*(.82-tier*.04)),tint)
			5: # broad commercial base and narrow illuminated spire
				part(0,c+Vector3.UP*h*.23,Vector3(w,h*.46,d),tint)
				part(0,c+Vector3.UP*h*.65,Vector3(w*.42,h*.7,d*.55),tint)
				part(2,c+Vector3(w*.22,h*.64,0),Vector3(2,h*.65,3),tint)
			6: # broad office block with a strongly offset square upper volume
				part(0,c+Vector3.UP*h*.32,Vector3(w,h*.64,d),tint)
				part(0,c+Vector3(w*.21,h*.82,-d*.12),Vector3(w*.48,h*.36,d*.65),tint)
			7: # L-shaped tower: two wings with a lower cross-wing
				part(0,c+Vector3(-w*.29,h*.5,0),Vector3(w*.42,h,d),tint)
				part(0,c+Vector3(w*.205,h*.32,d*.29),Vector3(w*.57,h*.64,d*.42),tint)
		build_roof(b)
		if b.get("landmark",false):
			# Thin metal mullions and service floors give foreground towers depth.
			for side in [-1,1]:
				for z in [-1,1]:
					part(3,c+Vector3(side*w*.39,h*.54,z*d*.41),Vector3(1.2,h*.92,1.2),tint)
			for floor_index in range(1,7):
				part(3,c+Vector3.UP*h*floor_index/7.,Vector3(w*.79,2.5,d*.83),tint)

	var architecture:=ShaderMaterial.new()
	architecture.shader=load("res://src/city.gdshader")
	architecture.set_shader_parameter("facade",load("res://assets/office-facade.png"))
	var glow:=ShaderMaterial.new()
	glow.shader=load("res://src/city_neon.gdshader")
	var cylinder:=CylinderMesh.new()
	cylinder.top_radius=.5
	cylinder.bottom_radius=.5
	cylinder.height=1
	cylinder.radial_segments=8
	for key in groups:
		var records:Array=groups[key]
		var mesh:Mesh=cylinder if key.y==1 else BoxMesh.new()
		var data:=batch(parent,mesh,glow if key.y==2 else architecture,records.size())
		for i in range(records.size()):
			if key.y==0 and records[i].transform.basis.get_scale().y>20. and records[i].transform.basis.get_scale().x>15. and records[i].transform.basis.get_scale().z>15.:
				reflection_boxes.append({"bounds":records[i].transform*AABB(Vector3.ONE*-.5,Vector3.ONE),"tint":records[i].color})
			data.set_instance_transform(i,records[i].transform)
			data.set_instance_color(i,accent.lerp(secondary,records[i].color.r) if key.y==2 else records[i].color)
	groups.clear()
	var ground:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(12000,12000)
	ground.mesh=plane
	ground.position.y=Layout.FLOOR-.5
	var streets:=ShaderMaterial.new()
	streets.shader=load("res://src/streets.gdshader")
	ground.material_override=streets
	parent.add_child(ground)
	build_billboards(parent)
	var paint:=mat(Color("657892"))
	paint.vertex_color_use_as_albedo=true
	traffic=batch(parent,BoxMesh.new(),paint,layout.routes.size()*2,2)
	cabins=batch(parent,BoxMesh.new(),mat(Color("121d34")),traffic.instance_count,2)
	lamps=batch(parent,BoxMesh.new(),mat(Color("8eeaff"),2),traffic.instance_count,2)
	animate(0)

func animate(time:float)->void:
	animation_time=time
	if obstacles: obstacles.moving.clear()
	for i in range(traffic.instance_count):
		var route:Dictionary=layout.routes[i/2]
		var along:=fposmod(time*(58+i%5*9)+i*173,route.length)
		var position:Vector3=route.start+Vector3.RIGHT*(along if route.direction>0 else route.length-along)
		var basis:=Basis(Vector3.UP,PI*.5*route.direction)
		traffic.set_instance_transform(i,Transform3D(basis.scaled(Vector3(4.8,1.6,9)),position))
		if obstacles: obstacles.moving.append(Transform3D(basis.scaled(Vector3(4.8,2.6,9)),position+Vector3.UP*.5))
		traffic.set_instance_color(i,Color("829cc0").lerp(Color("c35494"),float(i%5)/5))
		cabins.set_instance_transform(i,Transform3D(basis.scaled(Vector3(3.4,1.0,4)),position+Vector3.UP*1.1))
		lamps.set_instance_transform(i,Transform3D(basis.scaled(Vector3(3.8,.35,8)),position-basis.z*7))

func build_billboards(parent:Node3D)->void:
	var materials:Array[ShaderMaterial]=[]
	for variant in range(4):
		var material:=ShaderMaterial.new()
		material.shader=load("res://src/billboard.gdshader")
		material.set_shader_parameter("artwork",load("res://assets/city-billboards.png"))
		material.set_shader_parameter("panel",float(variant))
		materials.append(material)
	var titles:=["NOVA", "FLUX MOTORS", "LIVING CITY", "ION"]
	var copy:=["BETTER TOMORROWS", "BEYOND THE ROAD", "ROOM TO GROW", "FEEL THE ENERGY"]
	for item in layout.billboards:
		var mount:=Node3D.new()
		parent.add_child(mount)
		mount.transform=item.transform
		var frame:=MeshInstance3D.new()
		var box:=BoxMesh.new()
		box.size=Vector3(item.size.x+1.2,item.size.y+1.2,.5)
		frame.mesh=box
		frame.material_override=mat(Color("101b2c"))
		mount.add_child(frame)
		var screen:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=item.size
		screen.mesh=quad
		screen.position.z=.3
		screen.material_override=materials[item.variant]
		mount.add_child(screen)
		# Visible screens cast a localized wash throughout the lap, not just at start.
		if local_lights.size()<48:
			var landmark:bool=layout.buildings[item.building].get("landmark",false)
			var light:=OmniLight3D.new()
			light.position=Vector3(0,-item.size.y*.22,12.)
			light.light_color=[Color("9caaff"),Color("7fcfff"),Color("b9db95"),Color("f7a8ca")][item.variant]
			light.light_energy=4.0 if landmark else 2.8
			light.omni_range=210. if landmark else clampf(item.size.y*1.2,75.,150.)
			light.omni_attenuation=1.8
			light.light_specular=.6
			light.shadow_enabled=false
			light.distance_fade_enabled=true
			light.distance_fade_begin=350.
			light.distance_fade_length=150.
			light.distance_fade_shadow=260.
			light.shadow_normal_bias=.3
			mount.add_child(light)
			local_lights.append(light)
		for line in range(2):
			var label:=Label3D.new()
			label.text=titles[item.variant] if line==0 else copy[item.variant]
			label.font_size=72 if line==0 else 30
			label.pixel_size=item.size.x/700.
			label.position=Vector3(0,-item.size.y*(.31 if line==0 else .40),.4)
			label.modulate=Color("dbf4ff")
			label.outline_size=0
			mount.add_child(label)

func build_roof(b:Dictionary)->void:
	var w:float=b.width
	var d:float=b.depth
	var h:float=b.height
	var c:Vector3=b.center+Vector3.UP*h
	if b.kind==0: w*=.78;d*=.82
	if b.kind==3: c.y+=h*.04;w*=.55;d*=.55
	if b.kind==7: c.x-=w*.29;w*=.42
	if b.kind==6: c.x+=w*.21;c.z-=d*.12;w*=.48;d*=.65
	if b.kind==2: w*=.54;d*=.54
	if b.kind==5: w*=.42;d*=.55
	if b.kind==1: c.x-=w*.255;w*=.36;d*=.72
	if b.kind==4: c.y-=h*.01;c.x+=w*.12;w*=.72;d*=.74
	var tint:Color=b.color
	var top:float=b.roof_height
	match b.roof:
		0: # simple roof with asymmetric utility housings
			part(3,c+Vector3(w*.17,4,-d*.18),Vector3(w*.26,8,d*.22),tint)
		1: # a large square penthouse, visibly offset from the main shaft
			part(0,c+Vector3(w*.11,top*.5,d*.08),Vector3(w*.65,top,d*.64),tint)
			c.y+=top
		2: # two rooftop volumes at different heights
			part(0,c+Vector3(-w*.21,top*.5,0),Vector3(w*.34,top,d*.62),tint)
			part(3,c+Vector3(w*.21,top*.27,d*.15),Vector3(w*.32,top*.54,d*.36),tint)
		3: # a small technical hut below the antenna cluster
			part(3,c+Vector3.UP*8,Vector3(w*.55,16,d*.48),tint)
			c.y+=16
		4: # stacked setback crown
			part(0,c+Vector3.UP*top*.35,Vector3(w*.74,top*.7,d*.74),tint)
			part(3,c+Vector3.UP*top*.84,Vector3(w*.38,top*.28,d*.38),tint)
			c.y+=top*.98
		5: # flat roof, tall radio mast
			part(3,c+Vector3.UP*4,Vector3(w*.4,8,d*.4),tint)
	# Some roofs are dark; others get a thin architectural strip, not a glowing lid.
	if b.roof in [1,4]:
		part(2,c+Vector3(0,1,d*.32),Vector3(w*.65,1.2,1.4),tint)
	if b.roof>=3:
		var mast:float=b.antenna
		part(3,c+Vector3.UP*mast*.5,Vector3(1.8,mast,1.8),tint)
		part(2,c+Vector3.UP*(mast+1),Vector3(2.6,2.6,2.6),Color(.9,.25,.15))
		for level in [0.45,0.72]:
			part(3,c+Vector3.UP*mast*level,Vector3(minf(w*.6,16),1.2,1.2),tint)
		if b.roof==3:
			for side in [-1,1]:
				part(3,c+Vector3(side*w*.22,mast*.32,0),Vector3(1.2,mast*.64,1.2),tint)
