shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
varying vec4 tint;
void vertex(){
    tint=COLOR;
    vec3 center=(MODELVIEW_MATRIX*vec4(0.,0.,0.,1.)).xyz;
    float diameter=length(MODELVIEW_MATRIX[0].xyz);
    vec2 projected=MODELVIEW_MATRIX[2].xy;
    vec2 along=normalize(projected+vec2(0.,.00001));
    vec2 across=vec2(-along.y,along.x);
    // Face each split-screen camera separately, retaining a short rounded trail.
    float reach=max(diameter,length(projected));
    VERTEX=center+vec3(across*(UV.x-.5)*diameter+along*(UV.y-.5)*reach,0.);
    MODELVIEW_MATRIX=mat4(1.);
}
void fragment(){
    vec2 p=UV*2.-1.;
    float radius=dot(p,p);
    float soft=exp(-radius*3.5)*(1.-smoothstep(.5,1.,radius));
    ALBEDO=mix(tint.rgb,tint.rgb*.7+vec3(.3),soft*.3)*1.3;
    ALPHA=soft*tint.a*.7;
}
