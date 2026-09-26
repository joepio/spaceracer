shader_type spatial;
render_mode cull_disabled;
uniform sampler2D bark_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
    vec3 normal_world=normalize(mat3(INV_VIEW_MATRIX)*NORMAL);
    float blend=abs(normal_world.x)/(abs(normal_world.x)+abs(normal_world.z)+.001);
    vec3 bark=mix(texture(bark_color,world.xy*vec2(.055,.014)).rgb,texture(bark_color,world.zy*vec2(.055,.014)).rgb,blend);
    float moss=smoothstep(.3,.85,sin(world.x*.022+world.z*.018)+sin(world.y*.018)*.3);
    ALBEDO=mix(bark*.55,bark*vec3(.32,.50,.20),moss*.65);
    ROUGHNESS=.94;
    SPECULAR=.16;
}
