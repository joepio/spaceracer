shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
    float grain=sin(world.x*2.+sin(world.z*1.4)+world.y*.03)*sin(world.z*1.9+world.y*.018);
    float moss=smoothstep(.05,.7,sin(world.x*.037+world.z*.027)+sin(world.y*.013)*.35);
    ALBEDO=mix(vec3(.14,.073,.037),vec3(.10,.17,.055),moss*.7)*(.72+grain*.22);
    ROUGHNESS=.92;
}
