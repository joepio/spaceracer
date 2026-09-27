extends RefCounted
## Building-mounted neon, in spatial batches. No floating labels or extra cameras.
const SignShader=preload("res://src/neon_sign.gdshader")
const PALETTE=[Color("38cfee"),Color("ffae58"),Color("ed589f"),Color("70a7ff")]
var groups:Dictionary={}
var signs:Array[Dictionary]=[]
var bounds:Array[AABB]=[]

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
			4: c+=Vector3(b.width*.12,b.height*.78,0);size*=Vector3(.72,.42,.74)
			5: c.y+=b.height*.65;size*=Vector3(.42,.7,.55)
			6: c.y+=b.height*.32;size*=Vector3(1.,.64,1.)
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
		# Keep art billboards as the dominant signs on the original landmark slabs.
		if b.kind==0 or distance>420.*420. or signs.size()>=64 or index%3==2: continue
		var delta:=nearest-c
		var normal:=Vector3(signf(delta.x),0,0) if absf(delta.x)>absf(delta.z) else Vector3(0,0,signf(delta.z))
		var on_x:=absf(normal.x)>.5
		var face_width:float=size.z if on_x else size.x
		var panel_size:=Vector2(minf(face_width*.7,38.),minf(size.y*.45,68.))
		if index%3==0: panel_size.y=minf(panel_size.x*.7,22.)
		var position:=c+normal*((size.x if on_x else size.z)*.5+.65)
		position.y=clampf(nearest.y+45.,c.y-size.y*.5+panel_size.y*.5+5.,c.y+size.y*.5-panel_size.y*.5-5.)
		var frame:=Basis(Vector3.UP.cross(normal),Vector3.UP,normal)
		var transform_value:=Transform3D(frame,position)
		var box:=transform_value*AABB(Vector3(-panel_size.x*.5-.5,-panel_size.y*.5-.5,-.5),Vector3(panel_size.x+1.,panel_size.y+1.,1.))
		if not b.bounds.encloses(box) or not layout.clear(box): continue
		var mount:=Node3D.new();mount.name="MountedNeon";parent.add_child(mount);mount.transform=transform_value
		var housing:=MeshInstance3D.new();var housing_mesh:=BoxMesh.new()
		housing_mesh.size=Vector3(panel_size.x+1.,panel_size.y+1.,1.)
		housing.mesh=housing_mesh;housing.material_override=scenery.mat(Color("091321"));mount.add_child(housing)
		var screen:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=panel_size
		screen.mesh=quad;screen.position.z=.52
		screen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new();material.shader=SignShader
		material.set_shader_parameter("neon_color",color);material.set_shader_parameter("style",float(index%3))
		screen.material_override=material;mount.add_child(screen)
		signs.append({"transform":transform_value.translated_local(Vector3(0,0,.22)),"size":panel_size,"variant":index%3,"neon":true,"color":color,"bounds":box})
		bounds.append(box)
		if scenery.obstacles: scenery.obstacles.add_box(transform_value.scaled_local(Vector3(panel_size.x+1.,panel_size.y+1.,1.)))
		light_candidates.append({"mount":mount,"color":color,"distance":distance,"district":floori(float(nearest_index)*16./track.nodes.size())})
	# Select the closest sign per stretch of track, not the first city lots generated.
	light_candidates.sort_custom(func(a:Dictionary,b:Dictionary):return a.distance<b.distance)
	var light_districts:Dictionary={}
	for candidate in light_candidates:
		if light_districts.has(candidate.district): continue
		light_districts[candidate.district]=true
		var light:=OmniLight3D.new();light.position.z=5.;light.light_color=candidate.color
		light.light_energy=3.5;light.omni_range=130.;light.omni_attenuation=1.5;light.light_specular=.8
		light.distance_fade_enabled=true;light.distance_fade_begin=280.;light.distance_fade_length=130.;light.distance_fade_shadow=220.
		candidate.mount.add_child(light);scenery.local_lights.append(light)
	var glow:=ShaderMaterial.new();glow.shader=load("res://src/city_neon.gdshader")
	glow.set_shader_parameter("energy",3.2)
	for key in groups:
		var records:Array=groups[key]
		var data:MultiMesh=scenery.batch(parent,BoxMesh.new(),glow,records.size(),1,false,false)
		for i in range(records.size()):
			data.set_instance_transform(i,records[i].transform);data.set_instance_color(i,records[i].color)
	groups.clear()
