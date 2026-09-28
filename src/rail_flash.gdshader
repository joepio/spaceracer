shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform float power=1.0;
void vertex() {
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(
		INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p=UV*2.0-1.0;
	float r=dot(p,p);
	float core=exp(-r*180.0);
	float halo=exp(-r*8.0);
	float streak=exp(-abs(p.x)*5.0-p.y*p.y*2200.0);
	float edge=1.0-smoothstep(0.65,1.0,length(p));
	ALBEDO=mix(vec3(0.08,0.6,1.0),vec3(0.85,0.98,1.0),core)*5.0;
	ALPHA=(core+halo*0.18+streak*0.3)*edge*power;
}
