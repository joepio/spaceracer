extends SceneTree
## Native snapshots of the actual Growing Guns port across its full lifetime.
const Blast=preload("res://src/blast_vfx.gd")
var failures:=0
var output:="C:/dev/ion-rush-captures/explosions"
func _initialize()->void:
	root.unfocusable=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
	call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok: failures+=1;push_error(message)
func capture()->Image:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func different(a:Image,b:Image)->int:
	var count:=0
	for y in range(0,a.get_height(),3):
		for x in range(0,a.get_width(),3):
			var c:=a.get_pixel(x,y)-b.get_pixel(x,y)
			if absf(c.r)+absf(c.g)+absf(c.b)>.035: count+=1
	return count
func run()->void:
	load("res://src/main.gd").configure_viewport_aa(root,1.)
	DirAccess.make_dir_recursive_absolute(output)
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(32,19,42);camera.look_at(Vector3(0,7,0));camera.current=true
	var env_node:=WorldEnvironment.new();var env:=Environment.new();env_node.environment=env
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("243744");env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_energy=.4;env.ambient_light_color=Color("b7c8d8")
	env.glow_enabled=RenderingServer.get_current_rendering_method()!="gl_compatibility";env.glow_intensity=.7;env.glow_hdr_threshold=1.2
	scene.add_child(env_node)
	var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(140,140);floor_mesh.mesh=plane
	var material:=StandardMaterial3D.new();material.albedo_color=Color("43565b");material.roughness=.3;floor_mesh.material_override=material;scene.add_child(floor_mesh)
	var blast:=Blast.new();scene.add_child(blast)
	var clean:=await capture()
	var frames:Array[Image]=[]
	for age in [.08,.22,.5,1.,1.8,2.5]:
		blast.show_blast(31,Vector3(0,2,0),age,18.)
		var picture:=await capture();frames.append(picture)
		picture.save_png(output.path_join("blast-%.2f.png"%age))
		if age<=1.8: check(different(clean,picture)>30,"Explosion visible through each fire/smoke stage: %.2f"%age)
	check(different(frames[1],frames[3])>200,"Fire transitions into distinct dark smoke")
	check(different(clean,frames[-1])<different(clean,frames[-2]),"Late smoke fades toward the clean scene")
	check(different(frames[-1],await capture())==0,"Pause freezes all GPU billows, embers and light")
	var materials:Array=[]
	for layer in blast.layers: materials.append(layer.material.get_instance_id())
	var child_count:=blast.get_child_count()
	for id in range(70): blast.show_blast(id,Vector3.ZERO,.2,18.)
	check(blast.get_child_count()==child_count,"Repeated explosions reuse a fixed set of render nodes")
	for i in range(blast.layers.size()): check(materials[i]==blast.layers[i].material.get_instance_id(),"Materials are reused across impacts")
	blast.render_at(4.)
	check(not blast.visible,"All layers expire after the smoke tail")
	check(different(clean,await capture())==0,"Expired effects leave no light, haze, or smoke behind")
	var heat_count:=0;var light_count:=0
	for i in range(16):
		var crowded:=Blast.new();scene.add_child(crowded);crowded.show_blast(i,Vector3.ZERO,.15)
		if crowded.heat.visible: heat_count+=1
		if crowded.flash.visible: light_count+=1
	check(heat_count<=3 and light_count<=10,"Concurrent blasts cap expensive heat shells and lights")
	print("BLAST_RENDER renderer=%s failures=%d"%[RenderingServer.get_current_rendering_method(),failures])
	scene.queue_free();await process_frame;quit(1 if failures else 0)
