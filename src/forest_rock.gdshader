shader_type spatial;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
    vec3 n=normalize(mat3(INV_VIEW_MATRIX)*NORMAL);
    float grain=sin(world.x*.21)*sin(world.z*.17)+sin(world.y*.28)*.4;
    float moss=smoothstep(.2,.75,n.y+grain*.15);
    ALBEDO=mix(vec3(.11,.16,.16),vec3(.13,.24,.07),moss)*(.9+grain*.12);
    ROUGHNESS=.87;
}
