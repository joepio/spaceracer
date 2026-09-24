shader_type spatial;
varying vec2 position;
void vertex(){position=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment(){
	vec2 cell=abs(mod(position+60.,120.)-60.);
	float road=max(step(51.,cell.x),step(51.,cell.y));
	float line=max(step(58.8,cell.x),step(58.8,cell.y));
	ALBEDO=mix(vec3(.025,.03,.05),vec3(.012,.018,.028),road);
	EMISSION=vec3(.10,.15,.20)*line*.08*exp(-length(VERTEX)*.0007);
	if(!OUTPUT_IS_SRGB){ALBEDO*=.20;EMISSION*=.3;}
	ROUGHNESS=.8;
}
