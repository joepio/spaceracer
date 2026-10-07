shader_type spatial;
// Loose reef boulders and arches, crusted like the seafloor around them.
uniform float race_time=0.;
varying vec3 world;
varying vec3 world_normal;
#include "res://src/ocean_reef.gdshaderinc"
void vertex(){
    world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);
}
void fragment(){
    vec3 n=normalize(world_normal);
    float distance_to_camera=length(VERTEX);
    vec3 color=reef_rock(world,n,distance_to_camera)*COLOR.rgb;
    ALBEDO=color;
    float light=caustic(world.xz/36.,race_time*.32)*max(n.y,0.)*(1.-smoothstep(150.,520.,distance_to_camera));
    EMISSION=color*vec3(.55,.9,1.)*light*.55;
    ROUGHNESS=.9;
    SPECULAR=.2;
}
