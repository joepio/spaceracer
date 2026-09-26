shader_type spatial;
render_mode cull_disabled;
uniform vec3 tint : source_color =vec3(.2,1.,.8);
uniform float wrecked=0.;
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
    float seam=1.-smoothstep(.002,.007,abs(fract((local_position.z+1.)*.7)-.5));
    float spine=1.-smoothstep(.20,.28,abs(local_position.x));
    float service=step(.67,abs(local_position.x))*step(.82,fract(local_position.z*1.8));
    vec3 paint=mix(tint*.65,tint*.95,smoothstep(-.2,.7,local_position.y));
    paint=mix(paint,vec3(.028,.040,.060),spine*.35+service*.14);
    ALBEDO=paint*(1.-seam*.65);
    ALBEDO=mix(ALBEDO,vec3(.018,.016,.015),wrecked);
    METALLIC=mix(.38,.65,spine);
    ROUGHNESS=mix(.23,.32,seam);
    SPECULAR=.6;
    CLEARCOAT=.8;
    CLEARCOAT_ROUGHNESS=.2;
}
