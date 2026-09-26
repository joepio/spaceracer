shader_type spatial;
render_mode cull_disabled;
uniform float race_time=0.;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){
    world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    VERTEX.y+=sin(world.x*.013+race_time*.65)*.32+cos(world.z*.018-race_time*.4)*.24;
}
void fragment(){
    float flow=noise(world.xz*.018+race_time*.03);
    float a=sin(world.x*.14+world.z*.055+flow*8.+race_time*1.1);
    float b=cos(world.z*.12+world.x*.045+flow*9.-race_time*.8);
    vec3 n=normalize(vec3(a*.045,1.,b*.035));
    NORMAL=normalize(mat3(VIEW_MATRIX)*n);
    ALBEDO=mix(vec3(.017,.085,.10),vec3(.027,.16,.16),a*.25+b*.15+.4);
    ROUGHNESS=.14+(a+b+2.)*.012;
    METALLIC=.32;SPECULAR=.8;
}
