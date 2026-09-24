shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
uniform float race_time=0.;
uniform float power=1.;
uniform float boost_amount=0.;
void fragment(){
	float across=abs(UV.x*2.-1.);
	float core=exp(-across*across*14.);
	float edge=1.-smoothstep(.45,1.,across);
	float tip=1.-smoothstep(.45,1.,UV.y);
	float flow=.78+.22*sin(UV.y*43.-race_time*65.);
	float diamonds=pow(.5+.5*cos(UV.y*30.-race_time*8.),5.);
	vec3 halo=mix(vec3(.04,.36,1.),vec3(.3,.22,1.),boost_amount);
	ALBEDO=mix(halo,vec3(.65,1.,1.),core)+vec3(.7,.9,1.)*core*diamonds;
	ALPHA=edge*tip*flow*(.24+core*.6)*power;
}
