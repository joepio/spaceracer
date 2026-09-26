shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never;
varying vec4 puff;
void vertex(){
    puff=INSTANCE_CUSTOM;
    float scale_x=length(MODEL_MATRIX[0].xyz);
    float scale_y=length(MODEL_MATRIX[1].xyz);
    MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*scale_x,INV_VIEW_MATRIX[1]*scale_y,INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment(){
    vec2 p=UV*2.-1.;
    float ripple=sin(p.x*12.+puff.z)*sin(p.y*11.-puff.z*1.7)*.075;
    float roundness=length(p)+ripple;
    float edge=1.-smoothstep(.5,1.,roundness);
    float cloud=.7+.3*sin(p.x*6.+puff.z)*sin(p.y*7.+puff.z);
    vec3 soot=mix(vec3(.055,.065,.08),vec3(.32,.34,.36),cloud);
    vec3 fire=mix(vec3(1.,.12,.015),vec3(1.,.7,.16),cloud);
    ALBEDO=mix(soot,fire,puff.y);
    EMISSION=fire*puff.y*2.;
    ALPHA=edge*puff.x*.7;
}
