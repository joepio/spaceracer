extends RefCounted
## A dense, instanced city; all architecture is validated against the road ribbon.
const Layout=preload("res://src/city_layout.gd")
var layout:RefCounted
var traffic:MultiMesh
var cabins:MultiMesh
var lamps:MultiMesh
var signs:Array[Node3D]=[]
var sign_material:ShaderMaterial
var animation_time:=0.0
var groups:Dictionary={}
var accent:Color
var secondary:Color

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

static func batch(parent:Node3D,mesh:Mesh,material:Material,count:int)->MultiMesh:
	var data:=MultiMesh.new()
	data.transform_format=MultiMesh.TRANSFORM_3D
	data.use_colors=true
	data.mesh=mesh
	data.instance_count=count
	var renderer:=MultiMeshInstance3D.new()
	renderer.multimesh=data
	renderer.material_override=material
	renderer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(renderer)
	return data

func part(kind:int,position:Vector3,size:Vector3,color:Color)->void:
	var key:=Vector3i(floori(position.x/640),kind,floori(position.z/640))
	if not groups.has(key): groups[key]=[]
	groups[key].append({"transform":Transform3D(Basis.IDENTITY.scaled(size),position),"color":color})

func build(parent:Node3D,race:RefCounted)->void:
	accent=race.track.theme[3]
	secondary=race.track.theme[4]
	layout=Layout.new(race.track)
	for b in layout.buildings:
		var c:Vector3=b.center
		var w:float=b.width
		var d:float=b.depth
		var h:float=b.height
		var tint:Color=b.color
		part(0,c+Vector3.UP*h*.07,Vector3(w,h*.14,d),tint)
		match b.kind:
			0: # slab with a rooftop communications mast
				part(0,c+Vector3.UP*h*.54,Vector3(w*.78,h*.92,d*.82),tint)
				part(0,c+Vector3.UP*(h+16),Vector3(3,32,3),tint)
			1: # paired residential towers on a common podium
				for side in [-1,1]: part(0,c+Vector3(side*w*.255,h*.55,0),Vector3(w*.36,h*.9,d*.72),tint)
			2: # three stepped terraces
				for tier in range(3):
					var scale_value:=1-tier*.23
					part(0,c+Vector3.UP*h*(.2+tier*.3),Vector3(w*scale_value,h*.4,d*scale_value),tint)
					part(2,c+Vector3.UP*h*(.4+tier*.3),Vector3(w*scale_value,1.8,d*scale_value),tint)
			3: # octagonal glass tower and inset penthouse
				part(1,c+Vector3.UP*h*.48,Vector3(w*.92,h*.96,d*.92),tint)
				part(1,c+Vector3.UP*h*.98,Vector3(w*.55,h*.12,d*.55),tint)
			4: # stacked offset office volumes
				for tier in range(3):
					part(0,c+Vector3(w*(.12 if tier%2==0 else -.12),h*(.22+tier*.28),0),Vector3(w*.72,h*.42,d*.82),tint)
			5: # broad commercial base and narrow illuminated spire
				part(0,c+Vector3.UP*h*.23,Vector3(w,h*.46,d),tint)
				part(0,c+Vector3.UP*h*.65,Vector3(w*.42,h*.7,d*.55),tint)
				part(2,c+Vector3(w*.22,h*.64,0),Vector3(2,h*.65,3),tint)
		part(2,c+Vector3.UP*(h-3),Vector3(w*.6,2,d*.65),tint)
	var architecture:=ShaderMaterial.new()
	architecture.shader=load("res://src/city.gdshader")
	architecture.set_shader_parameter("accent",Vector3(accent.r,accent.g,accent.b))
	architecture.set_shader_parameter("secondary",Vector3(secondary.r,secondary.g,secondary.b))
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
	build_signs(parent)
	var paint:=mat(Color("657892"))
	paint.vertex_color_use_as_albedo=true
	traffic=batch(parent,BoxMesh.new(),paint,layout.routes.size()*2)
	cabins=batch(parent,BoxMesh.new(),mat(Color("121d34")),traffic.instance_count)
	lamps=batch(parent,BoxMesh.new(),mat(Color("8eeaff"),2),traffic.instance_count)
	animate(0)

func build_signs(parent:Node3D)->void:
	sign_material=ShaderMaterial.new()
	sign_material.shader=load("res://src/sign.gdshader")
	var names:=["ION DISTRICT","NIGHT MARKET","FLUX MOTORS","SKYLINE EXPRESS","NOVA ARCADE","NEON HEIGHTS"]
	for i in range(layout.signs.size()):
		var sign_node:=Node3D.new()
		parent.add_child(sign_node)
		sign_node.transform=layout.signs[i].transform
		signs.append(sign_node)
		var board:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=Vector2(44,18)
		board.mesh=quad
		board.material_override=sign_material
		sign_node.add_child(board)
		for line_index in range(2):
			var label:=Label3D.new()
			label.text=names[i%names.size()] if line_index==0 else "24 / 7   //   CITY NETWORK"
			label.font_size=64 if line_index==0 else 36
			label.pixel_size=.065
			label.position=Vector3(0,2 if line_index==0 else -3,.15)
			label.modulate=Color("d3ffff") if line_index==0 else Color("ff70c9")
			label.outline_size=0
			label.no_depth_test=false
			sign_node.add_child(label)

func animate(time:float)->void:
	animation_time=time
	sign_material.set_shader_parameter("race_time",time)
	for i in range(signs.size()):
		signs[i].position=layout.signs[i].transform.origin+Vector3.UP*sin(time*.65+i)*1.5
	for i in range(traffic.instance_count):
		var route:Dictionary=layout.routes[i/2]
		var along:=fposmod(time*(58+i%5*9)+i*173,route.length)
		var position:Vector3=route.start+Vector3.RIGHT*(along if route.direction>0 else route.length-along)
		var basis:=Basis(Vector3.UP,PI*.5*route.direction)
		traffic.set_instance_transform(i,Transform3D(basis.scaled(Vector3(4.8,1.6,9)),position))
		traffic.set_instance_color(i,Color("829cc0").lerp(Color("c35494"),float(i%5)/5))
		cabins.set_instance_transform(i,Transform3D(basis.scaled(Vector3(3.4,1.0,4)),position+Vector3.UP*1.1))
		lamps.set_instance_transform(i,Transform3D(basis.scaled(Vector3(3.8,.35,8)),position-basis.z*7))
