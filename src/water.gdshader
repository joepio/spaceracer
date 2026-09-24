shader_type spatial;
render_mode cull_disabled;
uniform vec3 accent=vec3(.1,.8,1.);
uniform float race_time=0.;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	vec2 p=world.xz*.008;
	float waves=sin(p.x+sin(p.y*.6+race_time*.18)*2.)*.5+.5;
	float channels=pow(max(0.,sin(p.y*.8+p.x*.23+race_time*.12)),20.);
	ALBEDO=mix(vec3(.013,.025,.07),accent*.12,waves);
	EMISSION=accent*channels*.08;
	METALLIC=.55;
	ROUGHNESS=.25;
}
