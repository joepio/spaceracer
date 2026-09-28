shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D wear_mask : filter_linear_mipmap, repeat_enable;
varying vec4 tint;
varying vec2 offset;
varying float camera_fade;
void vertex(){
    tint=COLOR;
    offset=vec2(float(INSTANCE_ID)*.173,float(INSTANCE_ID)*.317);
    vec3 center=(MODELVIEW_MATRIX*vec4(0.,0.,0.,1.)).xyz;
    float diameter=length(MODELVIEW_MATRIX[0].xyz);
    VERTEX=center+vec3(VERTEX.xy*diameter,0.);
    camera_fade=smoothstep(1.,4.,-center.z);
    MODELVIEW_MATRIX=mat4(1.);
}
void fragment(){
    vec2 p=UV*2.-1.;
    float noise=texture(wear_mask,UV*.65+offset).b;
    float density=smoothstep(.17,.73,noise);
    float edge=1.-smoothstep(.18,.96,length(p)+(noise-.5)*.16);
    ALBEDO=tint.rgb*mix(.65,1.15,noise);
    ALPHA=edge*density*tint.a*camera_fade;
}
