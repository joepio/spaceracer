shader_type spatial;
uniform vec3 accent=vec3(.1,.8,1.);
uniform vec3 secondary=vec3(1.,.2,.6);
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 tint;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);tint=COLOR.rgb;}
void fragment(){
	float face=abs(world_normal.x)>.5 ? world_position.z : world_position.x;
	float floor_height=mix(7.,13.,tint.g);
	float row=floor(world_position.y/floor_height);
	float column=floor(face/7.);
	float lit=step(.34,fract(sin(row*12.31+column*7.13+tint.r*58.)*437.13));
	float window=step(.2,fract(face/7.))*step(.35,fract(world_position.y/floor_height));
	float style=step(.5,tint.b);
	window=mix(window,step(.72,fract(world_position.y/floor_height)),style)*lit;
	vec3 neon=mix(accent,secondary,step(.6,tint.r));
	neon=mix(neon,vec3(1.,.66,.3),step(.75,tint.g));
	ALBEDO=mix(vec3(.025,.035,.06),vec3(.07,.095,.13),tint.b);
	float haze=exp(-length(VERTEX)*.00045);
	EMISSION=(neon*window*.48+neon*step(.975,fract(face/34.))*.07)*haze;
	METALLIC=.5;
	ROUGHNESS=.38;
}
