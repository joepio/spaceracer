shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float age=0.;
uniform float strength=1.;
uniform bool shutdown=false;
varying vec3 direction;
void vertex(){ direction=normalize(VERTEX); }
void fragment(){
	vec3 d=normalize(direction);
	float longitude=atan(d.z,d.x);
	float latitude=asin(clamp(d.y,-1.,1.));
	float jagged=sin(longitude*19.+age*47.)*.035+sin(longitude*43.-age*31.)*.018;
	float bolt=pow(max(0.,1.-abs(sin(latitude*(shutdown?5.:13.)+jagged*14.+age*8.))*(shutdown?5.:12.)),3.);
	float meridian=pow(max(0.,1.-abs(sin(longitude*(shutdown?4.:9.)+sin(latitude*27.+age*24.)*.22))*(shutdown?7.:18.)),3.);
	float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),3.5);
	float grid=shutdown?0.:pow(max(0.,1.-abs(sin(latitude*42.))*11.),3.)*.1;
	float flicker=.75+.25*sin(age*93.+longitude*7.);
	vec3 cyan=vec3(.12,.65,1.);
	vec3 violet=vec3(.48,.16,1.);
	vec3 tint=mix(cyan,violet,.5+.5*sin(longitude*3.+age*9.));
	float electric=(bolt+meridian*.45)*flicker;
	ALBEDO=tint;
	EMISSION=tint*(rim*1.7+electric*2.)+vec3(.6,.9,1.)*electric;
	float fade=shutdown?1.:1.-smoothstep(.65,1.05,age);
	ALPHA=clamp((electric*(shutdown?.65:.4)+rim*(shutdown?.1:.24)+grid)*strength*fade,0.,.8);
}
