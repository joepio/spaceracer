shader_type sky;
uniform vec3 top_color=vec3(.0024,.004,.008);
uniform vec3 horizon_color=vec3(.0075,.013,.024);

float hash(vec2 p){vec3 q=fract(vec3(p.xyx)*.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}
float noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float clouds(vec2 p){
    float v=0.,w=.55;
    for(int i=0;i<4;i++){v+=noise(p)*w;p=p*2.03+vec2(7.1,3.3);w*=.5;}
    return v;
}
void sky(){
    // A deep night gradient over a warm city-light dome on the horizon.
    vec3 ray=normalize(EYEDIR);
    float elevation=clamp(ray.y,0.,1.);
    float horizon=pow(1.-elevation,3.);
    vec3 color=mix(top_color,horizon_color,horizon);
    float dome=pow(1.-elevation,9.);
    color+=vec3(.05,.022,.034)*dome+vec3(.012,.018,.035)*pow(1.-elevation,4.);
    // Stars thin out into the light pollution near the skyline.
    vec2 grid=vec2(atan(ray.x,ray.z)*160.,asin(clamp(ray.y,-1.,1.))*160.);
    vec2 cell=floor(grid);
    float star=hash(cell);
    vec2 offset=fract(grid)-.5-(vec2(hash(cell+3.1),hash(cell+7.7))-.5)*.6;
    float twinkle=step(.985,star)*smoothstep(.16,0.,length(offset))*(.4+.6*hash(cell+1.3));
    color+=vec3(.75,.82,1.)*twinkle*smoothstep(.08,.45,ray.y)*.9;
    // Moon, with a soft halo, sits where the city's moonlight comes from.
    vec3 moon_dir=LIGHT0_ENABLED?normalize(-LIGHT0_DIRECTION):normalize(vec3(.4,.55,-.5));
    float facing=dot(ray,moon_dir);
    float disc=smoothstep(.99955,.9997,facing);
    vec2 surface=(ray-moon_dir*facing).xy*900.;
    float maria=.78+.22*noise(surface*.35+4.);
    color+=vec3(.85,.9,1.)*disc*maria*1.6;
    color+=vec3(.16,.2,.32)*pow(max(facing,0.),220.)*.6+vec3(.04,.05,.09)*pow(max(facing,0.),18.)*.5;
    // Low stratus drifts above the towers, lit magenta and amber from below.
    if(ray.y>.0){
        vec2 p=ray.xz/(ray.y+.18)*1.4;
        float shape=clouds(p+vec2(2.3,8.1));
        float cover=smoothstep(.5,.78,shape)*smoothstep(.0,.08,ray.y)*(1.-smoothstep(.35,.7,ray.y));
        vec3 underlit=mix(vec3(.055,.03,.06),vec3(.11,.055,.07),pow(1.-elevation,5.));
        color=mix(color,underlit+vec3(.03,.035,.05)*pow(max(facing,0.),6.),cover*.85);
    }
    COLOR=color;
}
