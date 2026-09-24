shader_type spatial;
uniform vec3 accent=vec3(.1,.8,1.);
uniform vec3 secondary=vec3(1.,.2,.6);
varying vec3 world_position;
varying vec3 tint;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;tint=COLOR.rgb;}
void fragment(){
    float rows=step(.73,fract(world_position.y/12.));
    float columns=step(.3,fract((world_position.x+world_position.z)/8.));
    float floors=step(.965,fract(world_position.y/48.));
    float blackout=step(.3,fract(sin(floor(world_position.y/12.)*8.+floor((world_position.x+world_position.z)/8.)*3.)*42.));
    vec3 neon=mix(accent,secondary,step(.5,tint.r));
    ALBEDO=mix(vec3(.025,.035,.065),vec3(.07,.10,.16),tint.b);
    EMISSION=neon*(rows*columns*blackout*.5+floors*.22);
    METALLIC=.4;
    ROUGHNESS=.45;
}
