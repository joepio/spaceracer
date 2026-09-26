shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float strength=0.;
void fragment(){
	float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.4);
	ALBEDO=vec3(.5,1.,.6);
	EMISSION=vec3(.6,1.,.45)*2.2;
	ALPHA=(.06+rim*.6)*strength;
}
