shader_type spatial;
render_mode cull_disabled;
uniform vec3 tint : source_color=vec3(.2,.8,.6);
uniform float metalness=.4;
uniform float seed=0.;
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){
    vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
               mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void fragment(){
    vec3 p=local_position*1.25+vec3(seed,seed*.37,seed*.71);
    float soot=noise(p)*.75+noise(p*3.2)*.25;
    float charred=smoothstep(.40,.64,soot);
    float grain=noise(p*19.);
    vec3 paint=tint*(.77+grain*.12);
    ALBEDO=mix(paint,vec3(.012,.009,.007)*( .65+grain*.5),charred*.97);
    METALLIC=mix(metalness,.04,charred);
    ROUGHNESS=mix(.32,.98,charred);
    SPECULAR=mix(.55,.15,charred);
    CLEARCOAT=(1.-charred)*.3;
}
