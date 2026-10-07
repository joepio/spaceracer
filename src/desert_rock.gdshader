shader_type spatial;
// Shared sandstone for hoodoos, boulders and arches. Vertex color carries the
// authored tint; world-space strata keep neighbouring rocks geologically aligned.
uniform bool vegetation=false;
varying vec3 world;
varying vec3 world_normal;
#include "res://src/desert_strata.gdshaderinc"
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){
    world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);
}
void fragment(){
    vec3 n=normalize(world_normal);
    if(vegetation){
        // Saguaro ribs: vertical grooves with pale spines catching the sun.
        float ribs=sin(atan(n.x,n.z)*12.)*.5+.5;
        ALBEDO=COLOR.rgb*(.72+ribs*.38)*(.9+noise(world.xz*2.+world.y)*.2);
        ROUGHNESS=.75;
        SPECULAR=.3;
    }else{
        vec4 sandstone_color=sandstone(world,n,length(VERTEX));
        vec3 stone=sandstone_color.rgb;
        NORMAL=normalize(mat3(VIEW_MATRIX)*normalize(n+vec3(0.,sandstone_color.a,0.)));
        // Wind-blown sand collects on every upward face.
        stone=mix(stone,vec3(.84,.60,.35),smoothstep(.72,.95,n.y)*.8);
        ALBEDO=stone*COLOR.rgb*(.95+noise(world.xz*1.3+world.y*.7)*.1);
        ROUGHNESS=.93;
        SPECULAR=.15;
    }
}
