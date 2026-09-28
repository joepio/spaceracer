shader_type spatial;
render_mode cull_back;
uniform float traffic_time=0.;
varying vec3 paint;
varying float surface;
void vertex(){
	float radius=12.;
	float straight=88.;
	float segment=straight+radius*1.570796327;
	float flow=traffic_time*INSTANCE_CUSTOM.y;
	// Coherent acceleration/creeping in a lane preserves gaps between cars.
	flow+=INSTANCE_CUSTOM.y*.85/.24*(sin(traffic_time*.24+INSTANCE_CUSTOM.w)-sin(INSTANCE_CUSTOM.w));
	float distance=mod(INSTANCE_CUSTOM.x+flow,segment*4.);
	float side=floor(distance/segment);
	float along=mod(distance,segment);
	vec2 pos;
	vec2 forward;
	if(along<straight){pos=vec2(-44.+along,-56.);forward=vec2(1.,0.);}
	else{
		float angle=(along-straight)/radius-1.570796327;
		pos=vec2(44.,-44.)+vec2(cos(angle),sin(angle))*radius;
		forward=vec2(-sin(angle),cos(angle));
	}
	float a=side*1.570796327;
	mat2 turn=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)));
	pos=turn*pos;forward=turn*forward;
	mat3 frame=mat3(vec3(forward.y,0.,-forward.x),vec3(0.,1.,0.),vec3(forward.x,0.,forward.y));
	VERTEX=frame*(VERTEX*.72)+vec3(pos.x,0.,pos.y);
	NORMAL=frame*NORMAL;
	paint=COLOR.rgb;surface=UV2.x;
}
void fragment(){
	ALBEDO=paint;METALLIC=.4;ROUGHNESS=.45;EMISSION=paint*.025;
	if(surface>3.5){ALBEDO=vec3(.009,.012,.016);METALLIC=0.;ROUGHNESS=.95;EMISSION=vec3(0.);}
	else if(surface>1.5){
		vec3 tint=surface<2.5 ? vec3(.90,.96,1.) : vec3(1.,.012,.004);
		ALBEDO=tint;EMISSION=tint*(surface<2.5 ? 8. : 6.);
	}else if(surface>.5){ALBEDO=vec3(.015,.026,.04);METALLIC=.6;ROUGHNESS=.28;EMISSION=vec3(0.);}
}
