extends SceneTree
## Native-render checks: heat really refracts pixels and flares obey occlusion.
const Ship=preload("res://src/ship.gd")
const Race=preload("res://src/race.gd")
var failures:=0
func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func box(parent:Node3D,at:Vector3,size_value:Vector3,color:Color)->MeshInstance3D:
	var mesh:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=size_value
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.mesh=shape;mesh.material_override=mat;parent.add_child(mesh);mesh.position=at
	return mesh
func capture()->Image:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func difference(a:Image,b:Image)->int:
	var changed:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var c:=a.get_pixel(x,y)-b.get_pixel(x,y)
			if absf(c.r)+absf(c.g)+absf(c.b)>.025: changed+=1
	return changed
func run()->void:
	load("res://src/main.gd").configure_viewport_aa(root,1.)
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera)
	camera.position=Vector3(0,7,-24);camera.look_at(Vector3(0,1,-5));camera.current=true
	box(scene,Vector3(0,-.2,-5),Vector3(50.,.4,60.),Color(.15,.18,.21))
	for i in range(-25,26):
		box(scene,Vector3(i,0,-5),Vector3(.07,.02,60.),Color(.7,.8,.9))
		box(scene,Vector3(0,0,i),Vector3(50.,.02,.07),Color(.7,.8,.9))
	var ship:=Ship.build(Color.CYAN);scene.add_child(ship);ship.position.y=1.7
	var p:Dictionary=Race.new([{"slot":0}],31).racers[0]
	p.engine_power=1.;p.thrust=1.;p.boost=1.;p.acceleration=100.
	Ship.animate_effects(ship,p,10.,0.)
	for child in ship.get_children():
		if child is Node3D: child.visible=false
	var heat:MeshInstance3D=ship.get_node("EngineHeat-1")
	var clean:=await capture()
	heat.visible=true
	var hot:=await capture()
	var heat_pixels:=difference(clean,hot)
	check(heat_pixels>30,"Heat ribbon visibly refracts the road grid")
	heat.material_override.set_shader_parameter("race_time",10.13)
	var animated:=await capture()
	check(difference(hot,animated)>20,"Heat turbulence animates with simulation time")
	var paused:=await capture()
	check(difference(animated,paused)==0,"Heat stops moving when simulation time is paused")
	heat.visible=false
	var arcs:MeshInstance3D=ship.get_node("BoostArcs-1");arcs.visible=true
	arcs.material_override.set_shader_parameter("strike_frame",10.)
	var electric:=await capture()
	var arc_pixels:=difference(clean,electric)
	check(arc_pixels>20,"Boost discharges draw multiple luminous spikes")
	arcs.material_override.set_shader_parameter("strike_frame",11.)
	var next_strike:=await capture()
	check(difference(electric,next_strike)>20,"Electrical branches change on the next render frame, even at the same physics time")
	check(difference(next_strike,await capture())==0,"Electrical branches freeze while paused")
	arcs.visible=false
	var wake:MultiMeshInstance3D=ship.get_node("EngineWake");wake.visible=true
	var soft_wake:=await capture()
	check(difference(clean,soft_wake)>20,"Soft exhaust wisps render visibly")
	wake.visible=false
	var flare:MeshInstance3D=ship.get_node("EngineFlare-1");flare.visible=true
	var lit:=await capture()
	var flare_pixels:=difference(clean,lit)
	check(flare_pixels>20,"Visible nozzle produces a subtle optical streak")
	var origin:=flare.global_position
	var wall:=box(scene,origin+(camera.position-origin).normalized()*2.,Vector3(1.2,1.2,.3),Color(.05,.05,.05))
	wall.look_at(camera.position)
	var occluded:=await capture()
	flare.visible=false
	var blocked:=await capture()
	var leak_pixels:=difference(occluded,blocked)
	check(leak_pixels<5,"A small object covering the nozzle hides the entire flare")
	print("JET_RENDER heat_pixels=%d arc_pixels=%d flare_pixels=%d occluded_leak=%d failures=%d"%[heat_pixels,arc_pixels,flare_pixels,leak_pixels,failures])
	scene.queue_free();await process_frame
	quit(1 if failures else 0)
