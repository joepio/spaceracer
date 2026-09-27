shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float power=1.;
uniform float phase=0.;
uniform float race_time=0.;
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
	float angle=atan(local_position.z,local_position.x);
	// Broken interference filaments instead of a solid expanding orange hoop.
	float islands=smoothstep(-.05,.65,sin(angle*5.+phase*2.1));
	islands*=smoothstep(-.3,.65,sin(angle*13.-phase*4.3));
	float grain=.55+.45*sin(angle*37.+sin(angle*11.)*2.+race_time*1.7);
	float soft_edge=pow(abs(dot(normalize(NORMAL),normalize(VIEW))),1.3);
	vec3 tint=mix(vec3(.28,.58,.70),vec3(.70,.47,.29),.5+.5*sin(angle*3.+phase*2.));
	ALBEDO=tint*(.35+grain*.25);
	ALPHA=clamp(power*islands*soft_edge*.22,0.,.18);
}
