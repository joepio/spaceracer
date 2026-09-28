shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float strength=0.;
void vertex(){
    MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment(){
    float radius=length(UV*2.-1.);
    float core=exp(-radius*radius*150.);
    float glow=exp(-radius*radius*14.);
    ALBEDO=vec3(1.,.97,.94)*(core*16.+glow*3.);
    ALPHA=(core+glow*.25)*strength*(1.-smoothstep(.65,1.,radius));
}
