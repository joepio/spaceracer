shader_type sky;
// Looking up from the deep: blue fading to black below, and Snell's window
// overhead where the rippled, sunlit surface squeezes the whole sky into a cone.
uniform vec3 top_color=vec3(.05,.34,.42);
uniform vec3 horizon_color=vec3(.02,.15,.2);
uniform vec3 sun_direction=vec3(.2,.9,.3);
float hash(vec2 p){vec3 q=fract(vec3(p.xyx)*.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
float noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void sky(){
    vec3 ray=normalize(EYEDIR);
    float up=ray.y;
    vec3 deep=vec3(.002,.016,.026);
    vec3 color=mix(horizon_color,deep,smoothstep(0.,-.55,up));
    color=mix(color,top_color,smoothstep(0.,.75,up));
    // Light shafts fan down from the window (no atan seam: noise on the unit xz).
    vec2 around=normalize(ray.xz+vec2(1e-4));
    float shafts=noise(around*9.)*.6+noise(around*23.)*.4;
    color+=vec3(.04,.16,.18)*pow(shafts,3.)*smoothstep(-.05,.5,up)*(1.-smoothstep(.55,.7,up))*1.6;
    // Snell's window with a rippled surface.
    float window=smoothstep(.6,.7,up);
    vec2 p=ray.xz/max(up,.05);
    float waves=noise(p*2.6)*.55+noise(p*6.1+3.)*.3+noise(p*15.)*.15;
    vec3 surface=mix(vec3(.18,.55,.62),vec3(.72,.95,1.),smoothstep(.35,.8,waves));
    color=mix(color,surface,window*.85);
    float sun=max(dot(ray,normalize(sun_direction)),0.);
    color+=vec3(.6,.9,1.)*(pow(sun,24.)*.45+pow(sun,260.)*1.2*(.5+.5*waves));
    COLOR=color;
}
