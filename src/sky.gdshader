shader_type sky;
uniform vec3 top_color=vec3(.015,.025,.07);
uniform vec3 horizon_color=vec3(.1,.2,.3);
void sky(){
	vec3 d=normalize(EYEDIR);
	float azimuth=atan(d.x,d.z);
	float clouds=.5+.5*sin(azimuth*3.+d.y*18.+sin(azimuth*7.)*.7);
	float haze=exp(-abs(d.y)*5.);
	COLOR=mix(top_color*.6,horizon_color*.36,haze)+vec3(.035,.05,.085)*clouds*haze;
}
