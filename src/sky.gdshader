shader_type sky;
uniform vec3 top_color=vec3(.015,.025,.07);
uniform vec3 horizon_color=vec3(.1,.2,.3);
uniform vec3 aurora_color=vec3(.6,.2,.9);
float hash(vec3 p){p=fract(p*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
void sky(){
    vec3 d=normalize(EYEDIR);
    vec3 base=mix(horizon_color*.55,top_color,smoothstep(-.1,.55,d.y));
    float longitude=atan(d.x,d.z);
    float ribbon=.22+.08*sin(longitude*2.)+.025*sin(longitude*7.);
    float aurora=exp(-abs(d.y-ribbon)*28.);
    float wisps=.6+.4*sin(longitude*28.+d.y*32.);
    base+=mix(aurora_color,vec3(.1,.7,.85),sin(longitude*2.)*.5+.5)*aurora*wisps*.17;
    vec3 grid=d*650.;
    float stars=step(.996,hash(floor(grid)))*pow(max(0.,1.-length(fract(grid)-.5)*1.65),2.);
    float haze=exp(-abs(d.y)*13.);
    COLOR=base+vec3(.7,.8,1.)*stars*smoothstep(-.03,.23,d.y)+aurora_color*haze*.06;
}
