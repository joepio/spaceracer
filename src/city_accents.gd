extends RefCounted
## Monumental corporate advertising, attached to facades and spatially batched.
const SignShader=preload("res://src/neon_sign.gdshader")
const PALETTE=[Color("b6d4f0"),Color("f89446"),Color("ecd378"),Color("8ebcaf"),Color("d27662"),Color("699ddd")]
const ASPECTS=[.5,.5,.5,.5,.5,.5]
const MAX_SIGNS=640
var groups:Dictionary={}
var signs:Array[Dictionary]=[]
var bounds:Array[AABB]=[]
var sign_groups:Dictionary={}
var sign_material:ShaderMaterial
var sign_renderers:Array[MultiMeshInstance3D]=[]

func animate(time:float)->void:
	if sign_material: sign_material.set_shader_parameter("race_time",time)

func strip(position:Vector3,size:Vector3,color:Color,layout:RefCounted,lot:AABB)->void:
	var box:=AABB(position-size*.5,size)
	if not lot.encloses(box) or not layout.clear(box): return
	var key:=Vector2i(floori(position.x/640.),floori(position.z/640.))
	if not groups.has(key): groups[key]=[]
	groups[key].append({"transform":Transform3D(Basis.IDENTITY.scaled(size),position),"color":color})
	bounds.append(box)

func build(scenery:RefCounted,parent:Node3D,track:RefCounted)->void:
	var layout:RefCounted=scenery.layout
	var light_candidates:Array[Dictionary]=[]
	var candidates:Array[Dictionary]=[]
	for index in range(layout.buildings.size()):
		var b:Dictionary=layout.buildings[index]
		var nearest:=Vector3.ZERO
		var distance:=INF
		var nearest_index:=0
		for node_index in range(track.nodes.size()):
			var n:Dictionary=track.nodes[node_index]
			var horizontal:=Vector2(n.p.x-b.center.x,n.p.z-b.center.z).length_squared()
			if horizontal<distance: distance=horizontal;nearest=n.p;nearest_index=node_index
		if distance>850.*850.: continue
		# Use actual facade volumes; strips never bridge a setback or float off a wall.
		var c:Vector3=b.center
		var size:=Vector3(b.width,b.height,b.depth)
		match int(b.kind):
			0: c.y+=b.height*.54;size*=Vector3(.78,.92,.82)
			1: c+=Vector3(-b.width*.255,b.height*.55,0);size*=Vector3(.36,.9,.72)
			2: c.y+=b.height*.8;size*=Vector3(.54,.4,.54)
			4: c+=Vector3(b.width*.12,b.height*.78,0);size*=Vector3(.72,.42,.74)
			5: c.y+=b.height*.65;size*=Vector3(.42,.7,.55)
			6: c+=Vector3(b.width*.21,b.height*.82,-b.depth*.12);size*=Vector3(.48,.36,.65)
			7: c+=Vector3(-b.width*.29,b.height*.5,0);size*=Vector3(.42,1.,1.)
			_: continue
		var color:Color=PALETTE[posmod(floori(b.center.x/600.)+floori(b.center.z/600.)+index%2,PALETTE.size())]
		if index%4!=3 or b.get("landmark",false):
			# Interrupted vertical ribs and a thin crown leave plenty of dark facade.
			for side in [-1.,1.]:
				for tier in range(3):
					var y:=c.y+size.y*(-.30+tier*.30)
					strip(Vector3(c.x+side*(size.x*.5-1.2),y,c.z+size.z*.5+.18),Vector3(1.5,size.y*.23,.48),color,layout,b.bounds)
					strip(Vector3(c.x+side*(size.x*.5-1.2),y,c.z-size.z*.5-.18),Vector3(1.5,size.y*.23,.48),color,layout,b.bounds)
					for zside in [-1.,1.]:
						strip(Vector3(c.x+side*(size.x*.5+.18),y,c.z+zside*(size.z*.5-1.2)),Vector3(.48,size.y*.23,1.5),color,layout,b.bounds)
				strip(c+Vector3(0,size.y*.5-.9,side*(size.z*.5+.18)),Vector3(size.x-.8,1.5,.48),color,layout,b.bounds)
				strip(c+Vector3(side*(size.x*.5+.18),size.y*.5-.9,0),Vector3(.48,1.5,size.z-.8),color,layout,b.bounds)
		if distance>750.*750.: continue
		var delta:=nearest-c
		# Tall corporate screens dominate both road-facing sides of large facades.
		for face in range(2):
			var normal:=Vector3(1. if delta.x>=0 else -1.,0,0) if face==0 else Vector3(0,0,1. if delta.z>=0 else -1.)
			var face_width:float=size.z if face==0 else size.x
			var accepted:Array[AABB]=[]
			for tier in range(2):
				var variant:=posmod(index*7+face*5+tier*11+track.seed_value,ASPECTS.size())
				var panel_size:=Vector2(minf(face_width*(.84 if tier==0 else .60),72. if tier==0 else 48.),0.)
				panel_size.y=panel_size.x/ASPECTS[variant]
				var max_height:=minf(160.,size.y*.72)
				if panel_size.y>max_height: panel_size*=max_height/panel_size.y
				if panel_size.x<10. or panel_size.y<10.: continue
				var position:=c+normal*((size.x if face==0 else size.z)*.5+.48)
				position.y=clampf(nearest.y+(65. if tier==0 else -80.),c.y-size.y*.5+panel_size.y*.5+6.,c.y+size.y*.5-panel_size.y*.5-6.)
				var frame:=Basis(Vector3.UP.cross(normal),Vector3.UP,normal)
				var transform_value:=Transform3D(frame,position)
				var box:=transform_value*AABB(Vector3(-panel_size.x*.5-.5,-panel_size.y*.5-.5,-.5),Vector3(panel_size.x+1.,panel_size.y+1.,1.04))
				if not b.bounds.encloses(box) or not layout.clear(box): continue
				if accepted.any(func(other:AABB):return other.grow(4.).intersects(box)): continue
				if layout.billboards.any(func(board:Dictionary):return board.bounds.grow(5.).intersects(box)): continue
				accepted.append(box)
				var tint:Color=PALETTE[variant]
				candidates.append({"transform":transform_value,"size":panel_size,"variant":variant,"neon":true,"color":tint,"bounds":box,
					"distance":distance,"district":floori(float(nearest_index)*16./track.nodes.size()),"priority":distance+float(tier)*45000.})
	# Prefer nearby facades throughout the lap over the first generated city lots.
	candidates.sort_custom(func(a:Dictionary,b:Dictionary):return a.priority<b.priority)
	for item in candidates.slice(0,MAX_SIGNS):
		var transform_value:Transform3D=item.transform
		var panel_size:Vector2=item.size
		var key:=Vector2i(floori(transform_value.origin.x/640.),floori(transform_value.origin.z/640.))
		if not sign_groups.has(key): sign_groups[key]=[]
		sign_groups[key].append(item)
		var reflection:Dictionary=item.duplicate();reflection.transform=transform_value.translated_local(Vector3(0,0,.22))
		signs.append(reflection);bounds.append(item.bounds)
		if scenery.obstacles: scenery.obstacles.add_box(transform_value.scaled_local(Vector3(panel_size.x+1.,panel_size.y+1.,1.)))
		light_candidates.append(item)
	build_panels(scenery,parent)
	# Select the closest sign per stretch of track, not the first city lots generated.
	light_candidates.sort_custom(func(a:Dictionary,b:Dictionary):return a.distance<b.distance)
	var light_districts:Dictionary={}
	for candidate in light_candidates:
		if light_districts.has(candidate.district): continue
		light_districts[candidate.district]=true
		if scenery.local_lights.size()>=64: break
		var light:=OmniLight3D.new();light.position=candidate.transform*Vector3(0,0,5.);light.light_color=candidate.color
		light.light_energy=3.5;light.omni_range=130.;light.omni_attenuation=1.5;light.light_specular=.8
		light.distance_fade_enabled=true;light.distance_fade_begin=280.;light.distance_fade_length=130.;light.distance_fade_shadow=220.
		light.shadow_enabled=false;parent.add_child(light);scenery.local_lights.append(light)
	var glow:=ShaderMaterial.new();glow.shader=load("res://src/city_neon.gdshader")
	glow.set_shader_parameter("energy",1.7)
	for key in groups:
		var records:Array=groups[key]
		var data:MultiMesh=scenery.batch(parent,BoxMesh.new(),glow,records.size(),1,false,false)
		for i in range(records.size()):
			data.set_instance_transform(i,records[i].transform);data.set_instance_color(i,records[i].color)
	groups.clear()

func build_panels(scenery:RefCounted,parent:Node3D)->void:
	sign_material=ShaderMaterial.new();sign_material.shader=SignShader
	sign_material.set_shader_parameter("corporate_atlas",load("res://assets/corporate-posters.png"))
	var housing_material:Material=scenery.mat(Color("091321"))
	var panel:=QuadMesh.new();panel.size=Vector2.ONE
	for key in sign_groups:
		var records:Array=sign_groups[key]
		var housings:MultiMesh=scenery.batch(parent,BoxMesh.new(),housing_material,records.size(),1,false,false)
		var data:=MultiMesh.new();data.transform_format=MultiMesh.TRANSFORM_3D
		data.use_colors=true;data.use_custom_data=true;data.mesh=panel;data.instance_count=records.size()
		var renderer:=MultiMeshInstance3D.new();renderer.name="CorporatePosters";renderer.multimesh=data
		renderer.material_override=sign_material;renderer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(renderer);sign_renderers.append(renderer)
		for i in range(records.size()):
			var item:Dictionary=records[i];var size:Vector2=item.size;var frame:Transform3D=item.transform
			housings.set_instance_transform(i,frame.scaled_local(Vector3(size.x+1.,size.y+1.,1.)))
			data.set_instance_transform(i,frame.translated_local(Vector3(0,0,.52)).scaled_local(Vector3(size.x,size.y,1.)))
			data.set_instance_color(i,item.color);data.set_instance_custom_data(i,Color(float(item.variant),0,0,0))
	sign_groups.clear()
