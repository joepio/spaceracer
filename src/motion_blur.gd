@tool
extends CompositorEffect
## Camera and object motion blur for one race view (Forward+ only: it needs
## Godot's velocity buffer). Main sets `strength` and `frame_time` each frame;
## streak length follows a fixed shutter, so it does not grow at low frame rates.
const SHUTTER := 1.0/60.0
var strength := 0.0
var frame_time := 1.0/60.0
var rd: RenderingDevice
var shader: RID
var pipeline: RID
var sampler: RID

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	needs_motion_vectors = true
	rd = RenderingServer.get_rendering_device()
	if rd: RenderingServer.call_on_render_thread(_setup)

func _setup() -> void:
	var spirv: RDShaderSPIRV = load("res://src/motion_blur.glsl").get_spirv()
	shader = rd.shader_create_from_spirv(spirv)
	if not shader.is_valid(): return
	pipeline = rd.compute_pipeline_create(shader)
	var state := RDSamplerState.new()
	state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler = rd.sampler_create(state)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd:
		for rid in [pipeline, shader, sampler]:
			if rid.is_valid(): rd.free_rid(rid)

func _render_callback(_type: int, render_data: RenderData) -> void:
	if strength <= .001 or not pipeline.is_valid(): return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null: return
	var size: Vector2i = buffers.get_internal_size()
	if size.x == 0 or size.y == 0: return
	if not buffers.has_texture(&"motion_blur", &"source"):
		buffers.create_texture(&"motion_blur", &"source", RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT,
			RenderingDevice.TEXTURE_SAMPLES_1, size, 1, 1, true, false)
	var scale := strength * SHUTTER / clampf(frame_time, 1.0/240.0, 1.0/20.0)
	var groups := Vector2i((size.x - 1) / 8 + 1, (size.y - 1) / 8 + 1)
	for view in buffers.get_view_count():
		var color: RID = buffers.get_color_layer(view)
		var velocity: RID = buffers.get_velocity_layer(view)
		if not color.is_valid() or not velocity.is_valid(): continue
		var source: RID = buffers.get_texture_slice(&"motion_blur", &"source", view, 0, 1, 1)
		var out := RDUniform.new()
		out.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE; out.binding = 0; out.add_id(color)
		var src := RDUniform.new()
		src.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE; src.binding = 1; src.add_id(sampler); src.add_id(source)
		var vel := RDUniform.new()
		vel.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE; vel.binding = 2; vel.add_id(sampler); vel.add_id(velocity)
		var copy := RDUniform.new()
		copy.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE; copy.binding = 3; copy.add_id(source)
		var set := UniformSetCacheRD.get_cache(shader, 0, [out, src, vel, copy])
		# Pass 1 copies the frame aside, pass 2 blurs from that copy.
		for pass_copy in [1.0, 0.0]:
			var push := PackedFloat32Array([size.x, size.y, scale, 48.0 * size.y / 720.0, pass_copy, 0, 0, 0])
			var list := rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(list, pipeline)
			rd.compute_list_bind_uniform_set(list, set, 0)
			rd.compute_list_set_push_constant(list, push.to_byte_array(), push.size() * 4)
			rd.compute_list_dispatch(list, groups.x, groups.y, 1)
			rd.compute_list_end()
