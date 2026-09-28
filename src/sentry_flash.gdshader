shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never,fog_disabled;
void vertex(){
    MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment(){
    vec2 p=UV*2.-1.;
    float r=dot(p,p);
    float core=exp(-r*70.);
    float halo=exp(-r*9.);
    ALBEDO=mix(vec3(1.,.44,.08),vec3(1.,.96,.78),core)*6.;
    ALPHA=(core+halo*.23)*(1.-smoothstep(.5,1.,length(p)));
}
