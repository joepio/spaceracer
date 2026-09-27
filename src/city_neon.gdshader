shader_type spatial;
uniform float energy=.9;
varying vec3 tint;
void vertex(){tint=COLOR.rgb;}
void fragment(){
	ALBEDO=tint*.35;
	EMISSION=tint*energy;
	METALLIC=.35;
	ROUGHNESS=.4;
}
