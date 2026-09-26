shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float power=1.;
void fragment(){
	ALBEDO=vec3(1.,.48,.12);
	EMISSION=vec3(1.,.32,.025)*1.3;
	ALPHA=power*.42;
}
