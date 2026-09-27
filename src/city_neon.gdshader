shader_type spatial;
varying vec3 tint;
void vertex(){tint=COLOR.rgb;}
void fragment(){
	ALBEDO=tint*.35;
	EMISSION=tint*.9;
	METALLIC=.35;
	ROUGHNESS=.4;
}
