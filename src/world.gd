extends Node3D
const Track = preload("res://src/track.gd")
const Scenery = preload("res://src/scenery.gd")
const Forest = preload("res://src/forest.gd")
const TurnMarkers = preload("res://src/turn_markers.gd")
const Obstacles=preload("res://src/obstacles.gd")
const CrashVfx=preload("res://src/crash_vfx.gd")
const RAIL_HEIGHT := 2.5
const Flight=preload("res://src/flight.gd")
const Chase=preload("res://src/chase.gd")
const Showpiece=preload("res://src/showpiece.gd")
var showpiece:RefCounted
const Ship = preload("res://src/ship.gd")
var scenery: RefCounted
var ships: Array[Node3D] = []
var crashes:Array[Node3D]=[]
var cameras: Array[Camera3D] = []
var race: RefCounted
var scene_environment:Environment
var advanced_renderer:=false
var lighting_quality:=1.0
var lighting_clock:=-1.0
var road_material: ShaderMaterial
var road_sections:Array[ShaderMaterial]=[]
var tunnel_material:ShaderMaterial
var tunnel_lights:Array[OmniLight3D]=[]
var ship_colors: Array[Color] = []
var forest_sun:DirectionalLight3D
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
	race.track.obstacles=Obstacles.new()
	var forest:bool=race.track.biome=="forest"
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	scene_environment=env
	advanced_renderer=RenderingServer.get_current_rendering_method()=="forward_plus"
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://src/forest_sky.gdshader" if forest else "res://src/sky.gdshader")
	var top:=Color("060a12")
	var horizon:=Color("0c121c")
	if forest: top=Color("2586d1");horizon=Color("b6e4f7")
	if RenderingServer.get_current_rendering_method()!="gl_compatibility":
		top=top.srgb_to_linear()
		horizon=horizon.srgb_to_linear()
	sky_material.set_shader_parameter("top_color",Vector3(top.r,top.g,top.b))
	sky_material.set_shader_parameter("horizon_color",Vector3(horizon.r,horizon.g,horizon.b))
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b7c2d2")
	env.ambient_light_energy = .28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("182437")
	env.fog_light_energy = .65
	env.fog_density = .00032
	env.fog_sky_affect = 0.0
	if forest:
		env.ambient_light_color=Color("d6e9f4")
		env.ambient_light_energy=.48
		env.tonemap_exposure=1.
		env.adjustment_enabled=true
		env.adjustment_contrast=1.1
		env.adjustment_saturation=1.08
		env.fog_light_color=Color("b6dcf0")
		env.fog_light_energy=1.
		env.fog_density=.00004
	if advanced_renderer:
		env.ssr_enabled=true
		env.ssr_max_steps=48
		env.ssr_depth_tolerance=.4
		env.ssao_enabled=true
		env.ssao_radius=2.
		env.ssao_intensity=1.1
		# Measured SSIL contribution is negligible in this open night scene.
		env.ssil_enabled=false
		env.ssil_intensity=1.5
		env.ssil_radius=4.
		env.glow_enabled=true
		env.glow_intensity=.7
		env.glow_hdr_threshold=1.2
		env.volumetric_fog_enabled=true
		env.volumetric_fog_density=.0012
		env.volumetric_fog_albedo=Color("7c94b1")
		env.volumetric_fog_length=180.
		env.volumetric_fog_ambient_inject=.12
		env.volumetric_fog_temporal_reprojection_amount=.65
		if forest:
			env.volumetric_fog_enabled=false
			env.glow_intensity=.35
	if RenderingServer.get_current_rendering_method()=="mobile":
		env.glow_enabled=true
		env.glow_intensity=.35 if forest else .7
		env.glow_hdr_threshold=1.2
	environment.environment = env
	add_child(environment)
	var night_fill := DirectionalLight3D.new()
	night_fill.rotation_degrees = Vector3(-35, -35, 0)
	night_fill.light_color = Color("d3e5ff")
	night_fill.light_energy = .18
	night_fill.light_specular = 0.0
	night_fill.shadow_enabled = false
	if forest:
		forest_sun=night_fill
		night_fill.rotation_degrees=Vector3(-48,-65,0)
		night_fill.light_color=Color("fff2d9")
		night_fill.light_energy=2.2
		sky_material.set_shader_parameter("sun_direction",night_fill.basis.z)
		night_fill.light_specular=.65
		night_fill.shadow_enabled=true
		night_fill.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		night_fill.directional_shadow_max_distance=380.
	add_child(night_fill)
	road_material = ShaderMaterial.new()
	road_material.shader = load("res://src/road.gdshader")
	tunnel_material=ShaderMaterial.new()
	tunnel_material.shader=load("res://src/tunnel.gdshader")
	scenery=Forest.new() if forest else Scenery.new()
	scenery.build(self,race)
	road_material.set_shader_parameter("billboard_art",load("res://assets/city-billboards.png"))
	build_track()
	showpiece=Showpiece.new()
	if forest: showpiece.probes=scenery.probes
	else: showpiece.build(self,race.track)
	race.track.obstacles.add_visual_boxes(self)
	for p in race.racers:
		var ship := build_ship(color_for(p))
		set_dynamic_layer(ship)
		add_child(ship)
		ships.append(ship)
		var crash:=CrashVfx.new();add_child(crash);crash.configure(ship);crashes.append(crash)
		ship_colors.append(color_for(p))
	update_ships()

func vertex(surface: SurfaceTool, n: Dictionary, x: float, h: float, uv: Vector2, normal:Vector3=Vector3.ZERO) -> void:
	surface.set_uv(uv)
	var zone := 1.0 if n.zone == "repair" else (2.0 if n.zone == "boost" else 0.0)
	surface.set_color(Color(zone / 2, 1.0 if n.loop else 0.0, 1.0 if n.get("brake_hint",false) else 0.0,1.-float(n.get("shape_angle",0.))/PI))
	surface.set_normal(normal if normal!=Vector3.ZERO else Track.surface_frame(n,x).y*(-1. if h<0 else 1.))
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
	dark.cull_mode=BaseMaterial3D.CULL_DISABLED
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
			var distance:float=i*race.track.step
			if a.get("air_gap",false): continue
			if maxf(a.split_gap,b.split_gap)>.0001:
				# Two separate decks around a real opening, tapering back to one road.
				for side in [-1.,1.]:
					fork_strip(surface,a,b,side,0.,distance)
					fork_strip(underside,a,b,side,-1.4,distance)
					inner_rail(rail,a,b,side,distance)
					fork_wall(underside,a,b,side,distance)
			else:
				var divisions:=24 if maxf(a.shape_angle,b.shape_angle)>.001 else 1
				for across in range(divisions):
					var left:float=-1.+2.*across/divisions
					var right:float=-1.+2.*(across+1)/divisions
					strip(surface,a,b,left,right,0.,distance)
					strip(underside,a,b,left,right,-1.4,distance)
			if a.rails and b.rails and not (Track.closed_tube(a) and Track.closed_tube(b)):
				strip(rail,a,b,-1.015,-1.,RAIL_HEIGHT,distance)
				strip(rail,a,b,1.,1.015,RAIL_HEIGHT,distance)
			if not (Track.closed_tube(a) and Track.closed_tube(b)):
				wall(underside,a,b,-1.,distance)
				wall(underside,a,b,1.,distance)
		var local_road:=road_material.duplicate() as ShaderMaterial
		road_sections.append(local_road)
		configure_reflections(local_road,nodes[mini(chunk+16,nodes.size()-1)].p,chunk<float(nodes.size())*.16)
		for pair in [[surface, local_road], [rail, rail_material], [underside, dark]]:
			var mesh := MeshInstance3D.new()
			mesh.mesh = pair[0].commit()
			mesh.material_override = pair[1]
			mesh.layers = 4 # Road excluded from static city captures; cameras still see it.
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(mesh)
	build_tunnel()
	build_jump_markers()
	TurnMarkers.build(self,race.track)
	# Tunnel ribs are static geometry.
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

func build_jump_markers()->void:
	var amber:=material(Color("ffc46b"),2.)
	var cyan:=material(Color("78e6ed"),2.)
	var metal:=material(Color("273747"))
	for jump in race.track.jumps:
		# Surface-mounted runway bars and edge beacons, no floating text signs.
		for marker in [[jump.takeoff-90.,amber],[jump.takeoff-55.,amber],[jump.takeoff-20.,amber],[jump.landing,cyan],[jump.landing+35.,cyan],[jump.landing+70.,cyan]]:
			var n:Dictionary=race.track.sample(marker[0])
			var frame:=Node3D.new()
			add_child(frame)
			frame.transform=Transform3D(n.frame,n.p)
			for side in [-1.,1.]:
				box(frame,Vector3(side*(n.width-1.),3.,0.),Vector3(.7,6.,.7),metal)
				box(frame,Vector3(side*(n.width-1.),5.5,0.),Vector3(.9,1.2,.9),marker[1])
				var stripe:=box(frame,Vector3(side*n.width*.65,.09,0.),Vector3(n.width*.55,.16,1.),marker[1])
				stripe.set_meta("track_surface",true)
		for distance in [jump.takeoff,jump.landing]:
			var n:Dictionary=race.track.sample(distance)
			var cap:=box(self,n.p-n.frame.y*.7,Vector3(n.width*2.,1.4,.35),metal)
			cap.basis=n.frame
			# Deck/lip impacts are resolved by Flight against the track ribbon.
			# An expanded scenery box would extend above hover height and catch
			# every launch/touchdown as if a wall crossed the road.
			cap.set_meta("track_surface",true)

func fork_strip(surface:SurfaceTool,a:Dictionary,b:Dictionary,side:float,height:float,distance:float)->void:
	var left_a:float=-a.width if side<0 else a.split_gap
	var right_a:float=-a.split_gap if side<0 else a.width
	var left_b:float=-b.width if side<0 else b.split_gap
	var right_b:float=-b.split_gap if side<0 else b.width
	for item in [[a,left_a,distance],[b,left_b,distance+race.track.step],[a,right_a,distance],
		[a,right_a,distance],[b,left_b,distance+race.track.step],[b,right_b,distance+race.track.step]]:
		vertex(surface,item[0],item[1],height,Vector2(item[1]/item[0].width,item[2]))

func inner_rail(surface:SurfaceTool,a:Dictionary,b:Dictionary,side:float,distance:float)->void:
	var left:=.35 if side<0 else 0.
	var right:=0. if side<0 else .35
	for item in [[a,left,distance],[b,left,distance+race.track.step],[a,right,distance],
		[a,right,distance],[b,left,distance+race.track.step],[b,right,distance+race.track.step]]:
		var lateral:float=side*(item[0].split_gap+item[1])
		vertex(surface,item[0],lateral,RAIL_HEIGHT,Vector2(lateral/item[0].width,item[2]))

func fork_wall(surface:SurfaceTool,a:Dictionary,b:Dictionary,side:float,distance:float)->void:
	for item in [[a,RAIL_HEIGHT,distance],[a,-1.4,distance],[b,RAIL_HEIGHT,distance+race.track.step],
		[b,RAIL_HEIGHT,distance+race.track.step],[a,-1.4,distance],[b,-1.4,distance+race.track.step]]:
		var lateral:float=side*item[0].split_gap
		vertex(surface,item[0],lateral,item[1],Vector2(lateral/item[0].width,item[2]),item[0].frame.x*side)

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
	tunnel.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(tunnel)

func wall(surface:SurfaceTool,a:Dictionary,b:Dictionary,side:float,distance:float)->void:
	var height:=RAIL_HEIGHT if a.rails and b.rails else 0.
	for item in [[a,height,distance],[a,-1.4,distance],[b,height,distance+race.track.step],
		[b,height,distance+race.track.step],[a,-1.4,distance],[b,-1.4,distance+race.track.step]]:
		vertex(surface,item[0],item[0].width*side,item[1],Vector2(side,item[2]),-Track.surface_frame(item[0],item[0].width*side).x*signf(side))

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
	for section in road_sections: section.set_shader_parameter("race_time",race.clock)
	tunnel_material.set_shader_parameter("race_time",race.clock)
	for i in range(tunnel_lights.size()): tunnel_lights[i].light_energy=1.4+1.2*(.5+.5*sin(race.clock*4-i*.8))
	if scenery: scenery.animate(race.clock)
	for i in range(race.racers.size()):
		var p: Dictionary = race.racers[i]
		Ship.animate_controls(ships[i],p)
		var n: Dictionary = race.track.sample(p.distance)
		ships[i].transform=Flight.pose(p,n,race.clock)
		ships[i].visible = not p.crashed
		ships[i].get_node("Body").material_override.set_shader_parameter("wrecked",1. if p.crashed else 0.)
		crashes[i].update(p,race.vfx_clock)
		var tint := color_for(p)
		if ship_colors[i] != tint:
			Ship.set_jet_tint(ships[i],tint)
			ships[i].get_node("Body").material_override.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
			for side in [-1,1]:
				var light:StandardMaterial3D=ships[i].get_node("Light%d"%side).material_override
				light.albedo_color=tint
				light.emission=tint
			ship_colors[i] = tint
		Ship.animate_effects(ships[i],p,race.vfx_clock,race.countdown)
	update_lighting()

func update_camera(camera: Camera3D, index: int, dt: float, snap: bool = false, effects_enabled:bool=true) -> void:
	var p: Dictionary = race.racers[index]
	var n:Dictionary=race.track.sample(p.distance)
	if p.crashed:
		var focus:Vector3=p.wreck.focus if p.wreck!=null else p.air_position
		Chase.update_crash(camera,p.air_position,focus,p.crash_id,dt,race.track.obstacles,snap)
		return
	Chase.update(camera,Flight.pose(p,n,race.clock),p.speed,p.boost>0 or p.on_pad,dt,snap,p.acceleration,effects_enabled and race.countdown<=0 and p.recovery<=0 and not p.finished)

static func set_dynamic_layer(node:Node)->void:
	if node is VisualInstance3D: node.layers=2
	for child in node.get_children(): set_dynamic_layer(child)

func set_quality(value:float,view_count:int)->void:
	lighting_quality=value
	lighting_clock=-1.
	if is_instance_valid(forest_sun):
		forest_sun.shadow_enabled=advanced_renderer and value>=.8
		forest_sun.directional_shadow_max_distance=220. if view_count>1 else 380.
	if not advanced_renderer: return
	scene_environment.ssil_enabled=false
	scene_environment.volumetric_fog_enabled=value>=1. and race.track.biome!="forest"
	scene_environment.ssr_enabled=value>=.8
	scene_environment.ssr_max_steps=32 if view_count>1 or value<1. else 48
	scene_environment.ssao_enabled=value>=1.
	scene_environment.glow_enabled=value>=.8

func update_lighting()->void:
	if showpiece==null or scenery==null: return
	if lighting_clock>=0 and race.vfx_clock-lighting_clock<.15: return
	lighting_clock=race.vfx_clock
	var lights:Array=showpiece.lights+scenery.local_lights
	var selected:Array[Light3D]=[]
	if advanced_renderer and lighting_quality>=.8:
		for i in range(race.racers.size()):
			if not race.racers[i].get("view",false): continue
			var position:Vector3=ships[i].global_position
			var candidates:Array=lights.duplicate()
			candidates.sort_custom(func(a:Light3D,b:Light3D):
				return a.global_position.distance_to(position)-(12. if a.shadow_enabled else 0.) < b.global_position.distance_to(position)-(12. if b.shadow_enabled else 0.))
			for light:Light3D in candidates.slice(0,2):
				if light.global_position.distance_to(position)<150. and not selected.has(light): selected.append(light)
	for light:Light3D in lights: light.shadow_enabled=selected.has(light)

func configure_reflections(material:ShaderMaterial,position:Vector3,detailed:bool)->void:
	if race.track.biome=="forest":
		material.set_shader_parameter("box_count",0)
		material.set_shader_parameter("sign_count",0)
		return
	var boxes:Array=scenery.reflection_boxes.filter(func(item:Dictionary): return item.bounds.end.y>position.y-40. and item.bounds.get_center().distance_to(position)<800.) if detailed else []
	boxes.sort_custom(func(a:Dictionary,b:Dictionary): return a.bounds.get_center().distance_squared_to(position)<b.bounds.get_center().distance_squared_to(position))
	var low:=PackedVector3Array()
	var high:=PackedVector3Array()
	var tint:=PackedColorArray()
	for item in boxes.slice(0,24):
		low.append(item.bounds.position)
		high.append(item.bounds.end)
		tint.append(item.tint)
	material.set_shader_parameter("box_count",low.size())
	low.resize(24);high.resize(24);tint.resize(24)
	material.set_shader_parameter("box_low",low)
	material.set_shader_parameter("box_high",high)
	material.set_shader_parameter("box_tint",tint)
	material.set_shader_parameter("city_art",load("res://assets/office-facade.png"))
	var signs:Array=scenery.layout.billboards.duplicate()
	signs.sort_custom(func(a:Dictionary,b:Dictionary): return a.transform.origin.distance_squared_to(position)<b.transform.origin.distance_squared_to(position))
	var centers:=PackedVector3Array()
	var right:=PackedVector3Array()
	var up:=PackedVector3Array()
	var data:=PackedVector3Array()
	for item in signs.slice(0,4):
		centers.append(item.transform.origin+item.transform.basis.z*.3)
		right.append(item.transform.basis.x)
		up.append(item.transform.basis.y)
		data.append(Vector3(item.size.x,item.size.y,item.variant))
	material.set_shader_parameter("sign_count",centers.size())
	centers.resize(4);right.resize(4);up.resize(4);data.resize(4)
	material.set_shader_parameter("sign_centers",centers)
	material.set_shader_parameter("sign_right",right)
	material.set_shader_parameter("sign_up",up)
	material.set_shader_parameter("sign_data",data)
