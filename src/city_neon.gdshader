shader_type spatial;
void fragment(){
	float haze=exp(-length(VERTEX)*.00045);
	ALBEDO=COLOR.rgb*.35;
	EMISSION=COLOR.rgb*.9*haze;
	METALLIC=.35;
	ROUGHNESS=.4;
}
