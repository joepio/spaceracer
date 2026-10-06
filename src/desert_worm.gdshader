shader_type spatial;
// Sandworm hide: grit-dusted plates outside (alpha 1), wet glistening flesh inside (alpha 0).
varying vec3 local;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){
    vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
               mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){local=VERTEX;}
void fragment(){
    float flesh=1.-COLOR.a;
    float grit=noise(local*9.)*.6+noise(local*31.)*.4;
    ALBEDO=COLOR.rgb*mix(.82+grit*.3,1.,flesh);
    ROUGHNESS=mix(.88-grit*.2,.22,flesh);
    SPECULAR=mix(.2,.7,flesh);
    // A faint sub-surface glow from the throat.
    EMISSION=vec3(.5,.12,.06)*flesh*.25;
    RIM=.35*(1.-flesh);
    RIM_TINT=.6;
}
