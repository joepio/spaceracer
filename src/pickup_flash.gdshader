shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float strength=0.;
uniform vec3 tint : source_color = vec3(.6,1.,.45);
void fragment(){
	float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.4);
	ALBEDO=tint;
	EMISSION=tint*2.2;
	ALPHA=(.06+rim*.6)*strength;
}
