shader_type spatial;
render_mode cull_back;
uniform float traffic_time=0.;
varying vec3 paint;
varying float surface;
void vertex(){
	// +Z is the nose; each instance's basis already faces its lane direction.
	VERTEX.z+=mod(INSTANCE_CUSTOM.x+traffic_time*INSTANCE_CUSTOM.y,INSTANCE_CUSTOM.z);
	paint=COLOR.rgb;
	surface=UV2.x;
}
void fragment(){
	ALBEDO=paint;
	METALLIC=.55;
	ROUGHNESS=.36;
	if(surface>.5 && surface<1.5){
		ALBEDO=vec3(.018,.038,.058);METALLIC=.7;ROUGHNESS=.23;
	}else if(surface>1.5){
		// Opaque emissive lenses: white at the nose, red at the rear.
		vec3 light_color=surface<2.5 ? vec3(.86,.94,1.) : vec3(1.,.012,.006);
		ALBEDO=light_color;
		EMISSION=light_color*(surface<2.5 ? 7. : 5.);
	}else{
		// A little self-fill keeps silhouettes legible without per-car lights.
		EMISSION=paint*.045;
	}
}
