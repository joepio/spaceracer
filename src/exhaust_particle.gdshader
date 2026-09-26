shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
varying vec4 tint;
varying float phase;
varying float camera_fade;
void vertex(){
    tint=COLOR;
    phase=float(INSTANCE_ID)*2.4;
    vec3 center=(MODELVIEW_MATRIX*vec4(0.,0.,0.,1.)).xyz;
    float diameter=length(MODELVIEW_MATRIX[0].xyz);
    vec3 start=(MODELVIEW_MATRIX*vec4(0.,0.,-.5,1.)).xyz;
    vec3 end=(MODELVIEW_MATRIX*vec4(0.,0.,.5,1.)).xyz;
    vec2 projected=end.xy/max(.1,-end.z)-start.xy/max(.1,-start.z);
    vec2 along=normalize(projected+vec2(0.,.00001));
    vec2 across=vec2(-along.y,along.x);
    // A ribbon along the real exhaust axis, not a circular camera-facing sprite.
    VERTEX=mix(start,end,UV.y)+vec3(across*(UV.x-.5)*diameter,0.);
    camera_fade=smoothstep(3.,9.,-center.z);
    MODELVIEW_MATRIX=mat4(1.);
}
void fragment(){
    float bend=sin(UV.y*9.+phase)*.15*sin(UV.y*3.14159);
    float across=UV.x*2.-1.+bend;
    float edge=exp(-across*across*4.)*(1.-smoothstep(.6,1.,abs(across)));
    float ends=smoothstep(0.,.22,UV.y)*(1.-smoothstep(.62,1.,UV.y));
    float broken=.7+.3*sin(UV.y*14.+phase);
    ALBEDO=tint.rgb*1.3;
    ALPHA=edge*ends*broken*tint.a*camera_fade;
}
