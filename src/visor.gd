extends Control
## One transparent instrument texture per player; the world camera stays untouched.
const CURVATURE:=.16
var surface:SubViewport
var projection:ShaderMaterial
var hud:Control

func setup(instruments:Control)->void:
	hud=instruments
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface=SubViewport.new()
	surface.disable_3d=true
	surface.transparent_bg=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(surface)
	surface.add_child(hud)
	var glass:=TextureRect.new()
	glass.texture=surface.get_texture()
	glass.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glass.mouse_filter=Control.MOUSE_FILTER_IGNORE
	projection=ShaderMaterial.new()
	projection.shader=load("res://src/visor.gdshader")
	projection.set_shader_parameter("curvature",CURVATURE)
	glass.material=projection
	add_child(glass)
	hud.visibility_changed.connect(sync_visibility)
	sync_visibility()

func set_resolution(pixels:Vector2i)->void:
	surface.size=Vector2i(maxi(16,pixels.x),maxi(16,pixels.y))
	hud.size=Vector2(surface.size)
	projection.set_shader_parameter("texel",Vector2.ONE/Vector2(surface.size))
	projection.set_shader_parameter("pixel_scale",maxf(.75,float(surface.size.y)/450.))

func sync_visibility()->void:
	visible=hud.visible
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED

func _process(_dt:float)->void:
	if not is_instance_valid(hud) or hud.race==null: return
	var p:Dictionary=hud.race.racers[hud.player_index]
	projection.set_shader_parameter("damage",clampf(p.flash,0.,1.))
	projection.set_shader_parameter("quiet",p.finished or hud.race.over)

static func project_marker(point:Vector2,dimensions:Vector2)->Vector2:
	# Inverse of the presentation: put a world marker at the texel sampled by
	# its intended screen position, so visor curvature cannot move it off target.
	var centered:=point/dimensions-Vector2.ONE*.5
	return (Vector2.ONE*.5+centered*(1.+CURVATURE*centered.length_squared()*4.))*dimensions
