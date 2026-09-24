extends Node3D
const Track = preload("res://src/track.gd")
const Scenery = preload("res://src/scenery.gd")
const Flight=preload("res://src/flight.gd")
const Chase=preload("res://src/chase.gd")
const Ship = preload("res://src/ship.gd")
var scenery: RefCounted
var ships: Array[Node3D] = []
var cameras: Array[Camera3D] = []
var race: RefCounted
var road_material: ShaderMaterial
var tunnel_material:ShaderMaterial
var tunnel_lights:Array[OmniLight3D]=[]
var ship_colors: Array[Color] = []
const PALETTE = [Color("53ffe0"), Color("ff617b"), Color("ffd16b"), Color("ac8cff"), Color("68baff"), Color("ff9f58"), Color("aaff78"), Color("f8aaff")]

static func color_for(p: Dictionary) -> Color:
	return Color.from_string(str(p.get("color", "")), PALETTE[int(p.slot) % PALETTE.size()])

static func material(color: Color, glow: float = 0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .38
	m.metallic = .35
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func build(state: RefCounted) -> void:
	race = state
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://src/sky.gdshader")
	var top:=Color("060a12")
	var horizon:=Color("0c121c")
	sky_material.set_shader_parameter("top_color",Vector3(top.r,top.g,top.b))
	sky_material.set_shader_parameter("horizon_color",Vector3(horizon.r,horizon.g,horizon.b))
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b7c2d2")
	env.ambient_light_energy = .48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("0c121c")
	env.fog_light_energy = .65
	env.fog_density = .00028
	env.fog_sky_affect = 0.0
	environment.environment = env
	add_child(environment)
	var night_fill := DirectionalLight3D.new()
	night_fill.rotation_degrees = Vector3(-35, -35, 0)
	night_fill.light_color = Color("d3e5ff")
	night_fill.light_energy = .18
	night_fill.light_specular = 0.0
	night_fill.shadow_enabled = false
	add_child(night_fill)
	road_material = ShaderMaterial.new()
	road_material.shader = load("res://src/road.gdshader")
	tunnel_material=ShaderMaterial.new()
	tunnel_material.shader=load("res://src/tunnel.gdshader")
	scenery=Scenery.new()
	scenery.build(self,race)
	build_track()
	for p in race.racers:
		var ship := build_ship(color_for(p))
		add_child(ship)
		ships.append(ship)
		ship_colors.append(color_for(p))
	update_ships()

func vertex(surface: SurfaceTool, n: Dictionary, x: float, h: float, uv: Vector2) -> void:
	surface.set_uv(uv)
	var zone := 1.0 if n.zone == "repair" else (2.0 if n.zone == "boost" else 0.0)
	surface.set_color(Color(zone / 2, 1.0 if n.loop else 0.0, 1.0 if n.get("brake_hint",false) else 0.0))
	surface.add_vertex(Track.point(n, x, h))

func strip(surface: SurfaceTool, a: Dictionary, b: Dictionary, left: float, right: float, height: float, distance: float) -> void:
	vertex(surface, a, a.width * left, height, Vector2(left, distance))
	vertex(surface, b, b.width * left, height, Vector2(left, distance + race.track.step))
	vertex(surface, a, a.width * right, height, Vector2(right, distance))
	vertex(surface, a, a.width * right, height, Vector2(right, distance))
	vertex(surface, b, b.width * left, height, Vector2(left, distance + race.track.step))
	vertex(surface, b, b.width * right, height, Vector2(right, distance + race.track.step))

func build_track() -> void:
	var nodes: Array = race.track.nodes
	var rail_material := material(race.track.theme[3], .55)
	var dark := material(Color("152236"))
	for chunk in range(0, nodes.size(), 32):
		var surface := SurfaceTool.new()
		var rail := SurfaceTool.new()
		var underside := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		rail.begin(Mesh.PRIMITIVE_TRIANGLES)
		underside.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(chunk, mini(chunk + 32, nodes.size())):
			var a: Dictionary = nodes[i]
			var b: Dictionary = nodes[(i + 1) % nodes.size()]
			strip(surface, a, b, -1, 1, 0, i * race.track.step)
			strip(rail, a, b, -1.015, -1, .65, i * race.track.step)
			strip(rail, a, b, 1, 1.015, .65, i * race.track.step)
			strip(underside, a, b, -1.09, 1.09, -1.4, i * race.track.step)
			wall(underside,a,b,-1.09,i*race.track.step)
			wall(underside,a,b,1.09,i*race.track.step)
		for pair in [[surface, road_material], [rail, rail_material], [underside, dark]]:
			pair[0].generate_normals()
			var mesh := MeshInstance3D.new()
			mesh.mesh = pair[0].commit()
			mesh.material_override = pair[1]
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mesh)
	build_tunnel()
	# Tunnel ribs and track-side turn chevrons are static geometry.
	var rib := material(Color("31465d"))
	for i in range(0, nodes.size(), 5):
		var n: Dictionary = nodes[i]
		if n.tunnel or i == 0:
			var frame := Node3D.new()
			add_child(frame)
			frame.transform = Transform3D(Track.basis_at(n), n.p)
			box(frame, Vector3(-n.width - 3, 11, 0), Vector3(1.7, 22, 2.2), rib)
			box(frame, Vector3(n.width + 3, 11, 0), Vector3(1.7, 22, 2.2), rib)
			box(frame, Vector3(0, 22, 0), Vector3(n.width * 2 + 8, 1.8, 2.2), rib)
			box(frame, Vector3(0, 20.8, -.1), Vector3(n.width * 2 + 4, .3, 1.3), rail_material)
		elif absf(n.curve) > .002:
			var sign_node := Node3D.new()
			add_child(sign_node)
			sign_node.transform = Transform3D(Track.basis_at(n), Track.point(n, -signf(n.curve) * (n.width + 2), 4))
			box(sign_node, Vector3.ZERO, Vector3(.5, 3, 6), rib)
			for z in [-1.5,1.5]:
				var marker:=box(sign_node,Vector3(0,0,z),Vector3(.7,.38,2),rail_material)
				marker.rotation.x=.65*signf(n.curve)

func build_tunnel()->void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(race.track.nodes.size()):
		var a:Dictionary=race.track.nodes[i]
		var b:Dictionary=race.track.nodes[(i+1)%race.track.nodes.size()]
		if not a.tunnel or not b.tunnel: continue
		if i%9==0:
			var light:=OmniLight3D.new()
			light.position=Track.point(a,0,14)
			light.light_color=Color("29dfff") if tunnel_lights.size()%2==0 else Color("ff3788")
			light.omni_range=65
			light.omni_attenuation=1.5
			light.shadow_enabled=false
			add_child(light)
			tunnel_lights.append(light)
		# Wall and roof vertices follow the same banked road frames as the racers.
		for panel in [Vector4(-1,0,-1,22),Vector4(1,22,1,0),Vector4(-1,22,1,22)]:
			for corner in [[0,0],[1,0],[0,1],[0,1],[1,0],[1,1]]:
				var node:Dictionary=a if corner[0]==0 else b
				var x:float=panel.x if corner[1]==0 else panel.z
				var h:float=panel.y if corner[1]==0 else panel.w
				surface.set_uv(Vector2(corner[1],(i+corner[0])*race.track.step))
				surface.add_vertex(Track.point(node,x*(node.width+3),h))
	surface.generate_normals()
	var tunnel:=MeshInstance3D.new()
	tunnel.name="NeonExpresswayTunnel"
	tunnel.mesh=surface.commit()
	tunnel.material_override=tunnel_material
	tunnel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tunnel)

func wall(surface:SurfaceTool,a:Dictionary,b:Dictionary,side:float,distance:float)->void:
	for item in [[a,0,distance],[a,-1.4,distance],[b,0,distance+race.track.step],
		[b,0,distance+race.track.step],[a,-1.4,distance],[b,-1.4,distance+race.track.step]]:
		vertex(surface,item[0],item[0].width*side,item[1],Vector2(side,item[2]))

static func box(parent: Node3D, position_value: Vector3, size_value: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size_value
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = position_value
	parent.add_child(mesh)
	return mesh

func build_ship(tint: Color) -> Node3D:
	return Ship.build(tint)

func update_ships() -> void:
	road_material.set_shader_parameter("race_time",race.clock)
	tunnel_material.set_shader_parameter("race_time",race.clock)
	for i in range(tunnel_lights.size()): tunnel_lights[i].light_energy=1.4+1.2*(.5+.5*sin(race.clock*4-i*.8))
	if scenery: scenery.animate(race.clock)
	for i in range(race.racers.size()):
		var p: Dictionary = race.racers[i]
		Ship.animate_controls(ships[i],p)
		var n: Dictionary = race.track.sample(p.distance)
		ships[i].transform=Flight.pose(p,n,race.clock)
		ships[i].visible = not (p.crashed and p.recovery>0) and (p.recovery<=0 or fmod(p.recovery,.2)<.1)
		var tint := color_for(p)
		if ship_colors[i] != tint:
			ships[i].get_node("Body").material_override.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
			for side in [-1,1]:
				var light:StandardMaterial3D=ships[i].get_node("Light%d"%side).material_override
				light.albedo_color=tint
				light.emission=tint
			ship_colors[i] = tint
		Ship.animate_effects(ships[i],p,race.vfx_clock,race.countdown)

func update_camera(camera: Camera3D, index: int, dt: float, snap: bool = false) -> void:
	var p: Dictionary = race.racers[index]
	var n:Dictionary=race.track.sample(p.distance)
	Chase.update(camera,Flight.pose(p,n,race.clock),p.speed,p.boost>0,dt,snap)
