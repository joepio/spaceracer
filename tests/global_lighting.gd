extends SceneTree
const Race=preload("res://src/race.gd")
const World=preload("res://src/world.gd")
var checks:=0
var failures:=0
func _initialize()->void: call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures+=1;push_error(message)
func dynamic_tree(node:Node)->void:
	if node is GeometryInstance3D: check(node.gi_mode==GeometryInstance3D.GI_MODE_DISABLED,"Moving hulls and effects cannot leave static GI ghosts")
	if node is Light3D: check(node.light_bake_mode==Light3D.BAKE_DISABLED,"Short-lived lights stay responsive direct illumination")
	for child in node.get_children(): dynamic_tree(child)
func run()->void:
	for biome in ["city","forest","cell","desert"]:
		var race:=Race.new([{"slot":0,"view":true}],31,3,"hard",biome)
		var world:=World.new();root.add_child(world);world.build(race)
		world.advanced_renderer=true # Exercise policy under the headless renderer too.
		world.bounce_lighting=true;world.set_quality(1.,3)
		check(world.scene_environment.sdfgi_enabled,"Desktop High supports the SDFGI experiment in three views")
		check(world.scene_environment.sdfgi_read_sky_light==(biome in ["forest","desert"]),"Only daytime Forest and Desert inject the sky into GI")
		var sources:=0
		for child in world.get_children():
			if child.has_meta("road_source"):
				sources+=1
				var source:MeshInstance3D=child.get_meta("road_source")
				check(source.gi_mode==GeometryInstance3D.GI_MODE_DISABLED,"Analytic reflections and pulsing tunnel materials do not emit into GI")
				check(child.visible and child.gi_mode==GeometryInstance3D.GI_MODE_STATIC,"GI captures a stable surface proxy")
				check(source.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Proxy never doubles the road shadow draw")
			if child is GeometryInstance3D and child.get_meta("gi_dynamic",false):
				check(child.gi_mode==GeometryInstance3D.GI_MODE_DISABLED,"Traffic and Cell walkers cannot become static occluders")
		check(sources>0,"Road proxy coverage exists")
		for ship in world.ships: dynamic_tree(ship)
		for crash in world.crashes: dynamic_tree(crash)
		dynamic_tree(world.weapon_vfx)
		world.set_quality(.6,3)
		check(not world.scene_environment.sdfgi_enabled,"Performance disables SDFGI")
		for child in world.get_children():
			if child.has_meta("road_source"):
				check(not child.visible and child.get_meta("road_source").cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"Direct fallback restores source shadows and removes proxy draws")
		world.advanced_renderer=false;world.set_quality(1.,1)
		check(not world.scene_environment.sdfgi_enabled,"Mobile/Compatibility never enable unsupported GI")
		if biome=="city": check(not world.city_moon.shadow_enabled,"Mobile avoids the added city directional shadow pass")
		world.free()
		await process_frame
	print("GLOBAL_LIGHTING_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
