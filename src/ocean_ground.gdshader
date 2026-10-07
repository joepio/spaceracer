shader_type spatial;
// Rippled pale sand between reefs of encrusted rock, under moving caustics.
uniform float floor_level=0.;
uniform vec3 sun_direction=vec3(.3,.9,.2);
uniform float race_time=0.;
varying vec3 world;
#include "res://src/ocean_reef.gdshaderinc"
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
    vec3 n=normalize(mat3(INV_VIEW_MATRIX)*NORMAL);
    float distance_to_camera=length(VERTEX);
    float near=1.-smoothstep(120.,600.,distance_to_camera);
    float patch=reef_noise(world.xz*.007)*.6+reef_noise(world.xz*.033)*.4;
    // Current ripples, shorter and softer than desert dunes.
    float phase=dot(world.xz,vec2(.57,.82))*.9+reef_noise(world.xz*.03)*6.;
    float ripple=sin(phase)*.5+.5;
    vec3 sand=mix(vec3(.36,.36,.3),vec3(.56,.54,.44),patch);
    sand=mix(sand,sand*1.08,pow(ripple,3.)*near);
    // Shell grit and dark weed debris in the troughs.
    sand*=.9+reef_noise(world.xz*1.1)*.2*near;
    sand=mix(sand,vec3(.24,.27,.2),smoothstep(.72,.9,reef_noise(world.xz*.09))*(1.-ripple)*.5);
    vec3 rock=reef_rock(world,n,distance_to_camera);
    float rocky=1.-smoothstep(.6,.86,n.y);
    vec3 color=mix(sand,rock,rocky);
    // Deeper water swallows more light.
    color*=mix(.62,1.,smoothstep(0.,140.,world.y-floor_level));
    ALBEDO=color;
    float light=caustic(world.xz/36.,race_time*.32)*max(n.y,0.)*(1.-smoothstep(150.,520.,distance_to_camera));
    EMISSION=color*vec3(.55,.9,1.)*light*.55;
    float slope=cos(phase)*.18*near*(1.-rocky);
    vec3 bent=normalize(n+vec3(.57,0.,.82)*slope);
    NORMAL=normalize(mat3(VIEW_MATRIX)*bent);
    ROUGHNESS=.92;
    SPECULAR=.2;
}
