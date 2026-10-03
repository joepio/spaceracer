shader_type spatial;
render_mode cull_disabled;
uniform vec3 tint=vec3(.2,1.,.8);
void fragment(){
	float panel=step(.95,fract(UV.y*3.));
	float inset=step(.47,UV.x)*step(UV.x,.53);
	float rim=pow(1.-max(dot(NORMAL,VIEW),0.),3.);
	ALBEDO=mix(tint*.65,tint,pow(max(dot(NORMAL,normalize(vec3(.2,.7,.4))),0.),.5))*(1.-panel*.22);
	ALBEDO=mix(ALBEDO,vec3(.025,.035,.06),inset*.8);
	METALLIC=.62;
	ROUGHNESS=.28;
	EMISSION=tint*rim*.22;
}
