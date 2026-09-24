shader_type spatial;
render_mode cull_disabled;
uniform float race_time=0.;
void fragment(){
	float edge=1.-smoothstep(.015,.05,min(UV.x,1.-UV.x));
	float band=1.-smoothstep(.012,.026,abs(UV.x-.28));
	float stripe=1.-smoothstep(.018,.035,abs(UV.x-.73));
	float chase=pow(.5+.5*sin(UV.y*.13-race_time*8.),6.);
	float panel=step(.965,fract(UV.y/18.));
	vec3 cyan=vec3(.05,.85,1.);
	vec3 magenta=vec3(1.,.06,.45);
	ALBEDO=vec3(.025,.035,.065)+vec3(.035,.06,.09)*panel;
	EMISSION=cyan*(edge*.75+band*(.3+chase*1.7))+magenta*stripe*(.4+chase)+cyan*chase*.035;
	METALLIC=.5;
	ROUGHNESS=.32;
}
