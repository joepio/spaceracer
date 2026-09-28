shader_type spatial;
varying vec2 position;
void vertex(){position=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment(){
	vec2 cell=abs(mod(position+60.,120.)-60.);
	float road=max(step(51.,cell.x),step(51.,cell.y));
	float along_x=step(59.55,cell.y)*(1.-step(47.,cell.x))*step(.42,fract(position.x/13.));
	float along_z=step(59.55,cell.x)*(1.-step(47.,cell.y))*step(.42,fract(position.y/13.));
	float crossing_x=step(44.,cell.x)*(1.-step(48.,cell.x))*step(52.,cell.y)*step(.45,fract(position.y/2.5));
	float crossing_z=step(44.,cell.y)*(1.-step(48.,cell.y))*step(52.,cell.x)*step(.45,fract(position.x/2.5));
	float markings=max(max(along_x,along_z),max(crossing_x,crossing_z));
	float curb=max(step(49.8,cell.x)*(1.-step(51.,cell.x)),step(49.8,cell.y)*(1.-step(51.,cell.y)))*(1.-road);
	ALBEDO=mix(vec3(.035,.042,.052),vec3(.018,.025,.034),road);
	ALBEDO=mix(ALBEDO,vec3(.25,.27,.26),markings*.75+curb*.18);
	EMISSION=vec3(.007,.010,.014)*road+vec3(.07,.09,.11)*(markings*.35+curb*.15);
	ROUGHNESS=.68;
}
