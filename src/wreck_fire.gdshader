shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
uniform float age=0.;
varying vec3 local_position;
varying float seed;
void vertex(){
    seed=INSTANCE_CUSTOM.x*50.;
    local_position=VERTEX;
    float tip=clamp(VERTEX.y+.5,0.,1.);
    VERTEX.x+=sin(age*17.+seed+VERTEX.y*7.)*tip*.14;
    VERTEX.z+=cos(age*13.+seed+VERTEX.y*6.)*tip*.12;
    VERTEX+=NORMAL*sin(VERTEX.y*19.-age*22.+seed)*.06*tip;
}
void fragment(){
    float tip=clamp(local_position.y+.5,0.,1.);
    float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
    float flicker=.75+.25*sin(age*23.+seed+tip*12.);
    float heat=clamp((1.-tip)*.7+facing*.25,0.,1.);
    ALBEDO=mix(vec3(1.,.10,.008),vec3(1.,.72,.22),smoothstep(.25,.85,heat))*3.8;
    ALPHA=smoothstep(0.,.16,age)*(1.-smoothstep(1.1,1.95,age))*pow(facing,1.4)*flicker;
}
