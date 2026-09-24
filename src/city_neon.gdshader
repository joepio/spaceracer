shader_type spatial;
varying vec3 tint;
void vertex(){tint=COLOR.rgb;}
void fragment(){
	float haze=exp(-length(VERTEX)*.00045);
	ALBEDO=tint*.35;
	EMISSION=tint*.9*haze;
	METALLIC=.35;
	ROUGHNESS=.4;
}
