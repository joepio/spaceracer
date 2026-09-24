shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float race_time=0.;
void fragment(){
	vec2 edge=abs(UV*2.-1.);
	float rim=step(.94,max(edge.x,edge.y));
	float sweep=pow(.5+.5*sin(UV.x*6.-race_time*1.7),12.);
	vec3 neon=mix(vec3(.05,.9,1.),vec3(1.,.08,.52),UV.x);
	ALBEDO=vec3(.018,.023,.06)+neon*(rim*(.6+sweep)+.035*step(.5,fract(UV.y*40.)));
}
