shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Camera-facing sand puffs. Instance alpha fades each puff; scale grows it.
varying float variant;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){
    vec3 scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
    MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*scale.x,INV_VIEW_MATRIX[1]*scale.y,INV_VIEW_MATRIX[2]*scale.z,MODEL_MATRIX[3]);
    MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
    variant=fract(MODEL_MATRIX[3].x*.013+MODEL_MATRIX[3].z*.017);
}
void fragment(){
    vec2 p=UV-.5;
    float d=length(p)*2.;
    float billow=noise(UV*4.+variant*17.)*.55+noise(UV*9.-variant*11.)*.45;
    float puff=smoothstep(1.,.15,d+billow*.3);
    // Sunlit crown, shaded underside, in the sand's own palette.
    vec3 lit=vec3(1.,.87,.68);
    vec3 shade=vec3(.68,.5,.34);
    ALBEDO=mix(shade,lit,clamp(.35+(.5-UV.y)*.9+billow*.3,0.,1.));
    ALPHA=COLOR.a*puff;
}
