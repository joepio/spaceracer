extends SceneTree
const Forest=preload("res://src/forest.gd")
var failures:=0

func _initialize()->void:
	root.unfocusable=true
	call_deferred("run")

func check(ok:bool,message:String)->void:
	if not ok:
		failures+=1
		push_error(message)

func solid_texture(color:Color)->ImageTexture:
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func luminance(viewport:SubViewport)->float:
	var image:=viewport.get_texture().get_image()
	var sum:=0.
	for y in range(100,156):
		for x in range(100,156):
			var pixel:=image.get_pixel(x,y)
			sum+=pixel.r*.2126+pixel.g*.7152+pixel.b*.0722
	return sum/(56.*56.)

func run()->void:
	for variant in range(Forest.Assets.PATHS.size()):
		for part in Forest.Assets.model(variant).parts:
			check(not part.material.backlight_enabled and not part.material.emission_enabled,"Authored foliage must not emit or glow through its underside")
			if part.leaves: check(part.material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,"Leaves use depth-writing cutouts")
	if DisplayServer.get_name()=="headless":
		print("FOLIAGE_GEOMETRY ",failures," failures (render contrast requires native renderer)")
		quit(1 if failures else 0)
		return
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(256,256)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color.BLACK
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=.05
	viewport.add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees.x=-90.
	sun.light_energy=1.65
	viewport.add_child(sun)
	var leaf:=MeshInstance3D.new()
	leaf.mesh=PlaneMesh.new()
	# Test the actual imported foliage material settings with a uniform albedo
	# fixture, isolating top/bottom light response from leaf texture coverage.
	var material:StandardMaterial3D
	for part in Forest.Assets.model(0).parts:
		if part.leaves: material=part.material.duplicate()
	material.albedo_texture=solid_texture(Color(.5,.7,.2))
	material.albedo_color=Color.WHITE
	material.normal_enabled=false
	material.roughness_texture=null
	leaf.material_override=material
	viewport.add_child(leaf)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=3.
	viewport.add_child(camera)
	var readings:Array[float]=[]
	for side in [1.,-1.]:
		camera.position=Vector3(0,side*4.,0)
		camera.look_at(Vector3.ZERO,Vector3.FORWARD)
		for frame in range(12): await process_frame
		await RenderingServer.frame_post_draw
		readings.append(luminance(viewport))
	check(readings[0]>.1 and readings[1]<readings[0]*.35,"Sunlit leaf top must be much brighter than its underside")
	print("FOLIAGE_LIGHTING ",JSON.stringify({"top":readings[0],"underside":readings[1],"ratio":readings[1]/maxf(.0001,readings[0]),"failures":failures}))
	viewport.queue_free()
	for frame in range(3): await process_frame
	quit(1 if failures else 0)
