shader_type canvas_item;
void fragment(){
	float shade=mix(.93,.08,smoothstep(.10,.78,UV.x));
	COLOR=vec4(.015,.025,.045,shade);
}
