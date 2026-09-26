extends Node3D
## Growing Guns fire/smoke, flame tongues and ember logic; see third_party/growing-guns.
static var billow_mesh:SphereMesh
static var ember_mesh:SphereMesh
static var budget_frame:=-1
static var heat_users:Dictionary={}
static var light_users:Dictionary={}
var layers:Array[Dictionary]=[]
var flash:OmniLight3D
var heat:MeshInstance3D
var serial:=-1
var radius:=16.
var duration:=2.58
var age:=0.

func _ready()->void:
	if billow_mesh==null:
		billow_mesh=SphereMesh.new();billow_mesh.radius=.5;billow_mesh.height=1.
		billow_mesh.radial_segments=24 if RenderingServer.get_current_rendering_method()=="mobile" else 32
		billow_mesh.rings=13 if RenderingServer.get_current_rendering_method()=="mobile" else 18
		ember_mesh=SphereMesh.new();ember_mesh.radius=.06;ember_mesh.height=.12;ember_mesh.radial_segments=5;ember_mesh.rings=3
	for kind in ["smoke","fire","tongues","embers"]:
		var data:=MultiMesh.new();data.transform_format=MultiMesh.TRANSFORM_3D;data.use_colors=true;data.use_custom_data=true
		data.mesh=ember_mesh if kind=="embers" else billow_mesh
		var mesh:=MultiMeshInstance3D.new();mesh.name=kind.capitalize();mesh.multimesh=data;mesh.layers=2
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat:=ShaderMaterial.new();mat.shader=load("res://src/blast_embers.gdshader" if kind=="embers" else "res://src/blast_billow.gdshader")
		mesh.material_override=mat;add_child(mesh)
		layers.append({"kind":kind,"mesh":mesh,"data":data,"material":mat,"life":1.,"rise":0.})
	flash=OmniLight3D.new();flash.shadow_enabled=false;flash.omni_attenuation=.42;flash.light_volumetric_fog_energy=.3;add_child(flash)
	heat=MeshInstance3D.new();heat.mesh=billow_mesh;heat.layers=2;heat.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var refract:=ShaderMaterial.new();refract.shader=load("res://src/blast_heat.gdshader");refract.render_priority=-4
	heat.material_override=refract;add_child(heat)
	visible=false

func configure(seed_value:int,blast_radius:float)->void:
	radius=blast_radius;duration=.5+radius*.13
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value+70039
	for layer in layers:
		var fire:bool=layer.kind in ["fire","tongues"]
		var tongue:bool=layer.kind=="tongues"
		var ember:bool=layer.kind=="embers"
		var count:int=clampi(int(radius*(5. if ember else .7 if tongue else .8 if fire else 1.1)),30 if ember else 5 if tongue else 6 if fire else 8,110 if ember else 12 if tongue else 18 if fire else 24)
		layer.life=.3+radius*.03 if ember else .34+radius*.05 if tongue else .35+radius*.055 if fire else duration
		layer.rise=0. if ember else radius*(.28 if tongue else .3 if fire else .7)
		var mm:MultiMesh=layer.data;mm.instance_count=count
		layer.mesh.custom_aabb=AABB(Vector3.ONE*(-radius*4.),Vector3.ONE*(radius*8.))
		var mat:ShaderMaterial=layer.material
		if ember:
			mat.set_shader_parameter("size_scale",1.2);mat.set_shader_parameter("elong_max",8.);mat.set_shader_parameter("brightness",5.)
		else:
			mat.set_shader_parameter("is_fire",1. if fire else 0.);mat.set_shader_parameter("tail_power",2.2 if fire else .38)
		for i in range(count):
			if ember:
				var theta:=rng.randf()*TAU;var elev:=rng.randf_range(-.2,1.35)
				var direction:=Vector3(cos(theta)*cos(elev),sin(elev),sin(theta)*cos(elev)).normalized()
				var distance:=radius*rng.randf_range(.8,2.)
				var travel:=direction*distance+Vector3.DOWN*radius*rng.randf_range(.2,.7)
				var size_value:=rng.randf_range(.4,1.15)
				var streak:=1.+clampf(distance/radius,0.,2.)*rng.randf_range(1.6,3.6)
				mm.set_instance_transform(i,Transform3D.IDENTITY)
				mm.set_instance_color(i,Color(size_value/1.2,clampf((streak-1.)/7.,0.,1.),1.,rng.randf_range(.6,1.)))
				mm.set_instance_custom_data(i,Color(travel.x,travel.y,travel.z,rng.randf_range(0.,.15)))
				continue
			var spread:=radius*(.45 if fire else .65)
			var angle:=rng.randf()*TAU;var rad:=rng.randf_range(0.,spread)
			var offset:=Vector3(cos(angle)*rad,rng.randf_range(-.2,.6)*radius*.45,sin(angle)*rad)
			var size_value:=radius*rng.randf_range(.28 if tongue else .3 if fire else .5,.6 if tongue else .7 if fire else 1.3)
			var axes:=Basis.IDENTITY.scaled(Vector3.ONE*size_value)
			if tongue:
				var azimuth:=rng.randf()*TAU;var elevation:=rng.randf_range(-.25,.85)
				var direction:=Vector3(cos(azimuth)*cos(elevation),sin(elevation),sin(azimuth)*cos(elevation))
				offset=direction*(rad+radius*.15)
				var across:=Vector3.UP.cross(direction).normalized()
				axes=Basis(across*size_value,direction*size_value*2.6,direction.cross(across)*size_value)
			mm.set_instance_transform(i,Transform3D(axes,offset))
			var seed:=rng.randf();var delay:float=(.14 if tongue else 0.)+rng.randf_range(0.,.22 if fire else .12)
			var warmth:=pow(1.-clampf(rad/maxf(spread,.001),0.,1.),1.4) if fire else rng.randf_range(.2,.55)
			var grey:=1. if fire else rng.randf_range(.07,.26)
			var body:=Color.WHITE if fire else Color(grey*1.08,grey,grey*.9)
			mm.set_instance_color(i,Color(body.r,body.g,body.b,rng.randf_range(.75,.95) if fire else rng.randf_range(.6,.85)))
			mm.set_instance_custom_data(i,Color(seed,delay,warmth,rng.randf_range(0.,.8)))

func show_blast(id:int,at:Vector3,elapsed:float,blast_radius:float=16.,light_dim:float=1.)->void:
	if serial!=id:
		serial=id;configure(id,blast_radius)
	position=at
	for layer in layers:
		if layer.kind!="embers": layer.material.set_shader_parameter("world_light_dim",light_dim)
	render_at(elapsed)

func render_at(elapsed:float)->void:
	age=maxf(0.,elapsed);visible=serial>=0 and age<duration
	if not visible: return
	for layer in layers:
		var phase:float=clampf(age/layer.life,0.,1.)
		layer.mesh.visible=phase<1.
		layer.mesh.position=Vector3.UP*(radius*.1+layer.rise*phase)
		layer.material.set_shader_parameter("anim",phase)
	# Same spike -> warm hold -> fade sequence, driven by race time instead of tweens.
	var light_life:=.5+radius*.025
	var strength:=lerpf(1.45,1.,smoothstep(.045,.1,age))*(1.-smoothstep(light_life*.5,light_life,age))
	flash.position=Vector3.UP*radius*.1
	flash.light_color=Color("fff0c0").lerp(Color("ff7b28"),clampf(age/light_life,0.,1.))
	flash.light_energy=(7.+radius*.4)*strength
	flash.omni_range=lerpf(maxf(10.,radius*.7),minf(92.,radius*2.2),clampf(age/light_life,0.,1.))
	var frame:=Engine.get_process_frames()
	if frame!=budget_frame: budget_frame=frame;heat_users.clear();light_users.clear()
	var id:=get_instance_id()
	if age<light_life and (light_users.size()<10 or light_users.has(id)): light_users[id]=true
	flash.visible=age<light_life and light_users.has(id)
	var heat_life:=clampf(.42+radius*.018,.42,.95)
	if age<heat_life and (heat_users.size()<3 or heat_users.has(id)): heat_users[id]=true
	heat.visible=age<heat_life and heat_users.has(id)
	var phase:=clampf(age/heat_life,0.,1.)
	heat.scale=Vector3.ONE*maxf(.01,radius*4.4*(1.-pow(2.,-10.*phase)))
	heat.material_override.set_shader_parameter("falloff",pow(1.-phase,3.))
