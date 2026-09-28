shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float race_time=0.0;
void fragment() {
	float level=round(COLOR.r*3.0);
	float frequency=level>2.5 ? 2.4 : (level>1.5 ? 1.35 : 0.65);
	float chase=0.5+0.5*sin(6.283185*(race_time*frequency-COLOR.g));
	float pulse=pow(chase,3.0);
	vec3 tint=level>2.5 ? vec3(1.0,0.015,0.008) : (level>1.5 ? vec3(1.0,0.16,0.008) : vec3(1.0,0.7,0.025));
	// Signs never blink off. Higher urgency increases sweep speed and contrast.
	float brightness=level>2.5 ? 1.4+pulse*4.0 : (level>1.5 ? 1.5+pulse*2.0 : 1.6+pulse*0.8);
	if(COLOR.b>0.75) { tint=vec3(0.7,0.91,1.0); brightness=1.5+pulse*0.5; }
	ALBEDO=tint*brightness;
	float radius=abs(UV.y*2.0-1.0)*2.8;
	float core=exp(-radius*radius*2.0);
	float halo=exp(-radius*radius*0.35)*0.16;
	ALPHA=(core+halo)*(1.0-smoothstep(2.2,2.8,radius));
}
