shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
uniform float power=0.;
void vertex(){
	// Per-view billboarding works for every split-screen camera without updates.
	mat4 facing=mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);
	MODELVIEW_MATRIX=VIEW_MATRIX*facing;
}
void fragment(){
	float r=length(UV*2.-1.);
	float halo=exp(-r*r*5.)*(1.-smoothstep(.65,1.,r));
	float hot=exp(-r*r*65.);
	ALBEDO=mix(vec3(.08,.46,1.),vec3(.8,1.,1.),hot);
	ALPHA=halo*(.06+power*.8)+hot*power*.6;
}
