shader_type spatial;
uniform vec3 tint=vec3(.8,.2,.5);
void fragment(){
	float bands=sin(UV.y*65.+sin(UV.x*19.)*.7)*.5+.5;
	float fine=sin(UV.y*180.+sin(UV.x*25.)*.3)*.5+.5;
	ALBEDO=mix(tint*.2,mix(tint,vec3(.9,.72,.53),.5),bands*.7+fine*.1);
	ROUGHNESS=.9;
	EMISSION=tint*.025;
}
