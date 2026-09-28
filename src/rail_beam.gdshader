shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform float power = 1.0;
uniform bool core = false;
void fragment() {
	float edge = pow(max(0.0, 1.0-abs(dot(normalize(NORMAL),normalize(VIEW)))), 1.5);
	vec3 tint = core ? vec3(0.8,0.96,1.0) : vec3(0.05,0.5,1.0);
	ALBEDO=tint*(core ? 10.0 : 2.5)*power;
	ALPHA=power*(core ? 1.0 : (0.12+edge*0.45));
}
