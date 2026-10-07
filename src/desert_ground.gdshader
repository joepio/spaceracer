shader_type spatial;
// Wind-rippled sand on the dunes; banded sandstone on every steep face.
uniform float floor_level=0.;
uniform vec3 sun_direction=vec3(.4,.5,.2);
varying vec3 world;
#include "res://src/desert_strata.gdshaderinc"
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
    vec3 n=normalize(mat3(INV_VIEW_MATRIX)*NORMAL);
    float near=1.-smoothstep(120.,700.,length(VERTEX));
    float patch=noise(world.xz*.006)*.6+noise(world.xz*.031)*.4;
    // Ripples run across the prevailing wind and bend with the dune noise.
    float phase=dot(world.xz,vec2(.82,.57))*.55+noise(world.xz*.02)*7.;
    float ripple=sin(phase)*.5+.5;
    vec3 sand=mix(vec3(.62,.39,.20),vec3(.86,.62,.36),patch);
    sand=mix(sand,sand*vec3(1.08,1.04,.98),pow(ripple,3.)*near);
    sand*=.92+noise(world.xz*.9)*.16*near;
    vec4 stone=sandstone(world,n,length(VERTEX));
    float rock=1.-smoothstep(.58,.84,n.y);
    // Sand drifts settle on terraces; the wash floor reads slightly darker.
    vec3 color=mix(sand,stone.rgb,rock);
    color*=mix(.78,1.,smoothstep(0.,30.,world.y-floor_level));
    ALBEDO=color;
    // Fine ripple relief catches the low sun near the camera.
    float slope=cos(phase)*.22*near*(1.-rock);
    vec3 bent=normalize(n+vec3(.82,0.,.57)*slope+vec3(0.,1.,0.)*stone.a*rock);
    NORMAL=normalize(mat3(VIEW_MATRIX)*bent);
    ROUGHNESS=mix(.97,.86,rock);
    SPECULAR=.18;
}
