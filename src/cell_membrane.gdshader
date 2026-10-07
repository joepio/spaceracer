shader_type spatial;
render_mode unshaded,cull_front;
uniform float race_time=0.;
varying vec3 cell_point;
void vertex(){cell_point=VERTEX*2.;}
vec3 hash3(vec3 p){
    p=vec3(dot(p,vec3(127.1,311.7,74.7)),dot(p,vec3(269.5,183.3,246.1)),dot(p,vec3(113.5,271.9,124.6)));
    return fract(sin(p)*43758.5453);
}
// Distance to the nearest cell border in a 3D Voronoi tiling.
vec3 voronoi(vec3 p){
    vec3 cell=floor(p),f=fract(p);
    float first=8.,second=8.,id=0.;
    for(int x=-1;x<=1;x++)for(int y=-1;y<=1;y++)for(int z=-1;z<=1;z++){
        vec3 o=vec3(float(x),float(y),float(z));
        vec3 r=o+hash3(cell+o)-f;
        float d=dot(r,r);
        if(d<first){second=first;first=d;id=hash3(cell+o+17.).x;}else if(d<second)second=d;
    }
    return vec3(sqrt(first),sqrt(second)-sqrt(first),id);
}
void fragment(){
    vec3 p=normalize(cell_point);
    float t=race_time;
    float flow=sin(p.x*11.+sin(p.z*8.)*1.8)+sin(p.y*17.+p.z*9.+sin(p.x*12.));
    float cloud=.5+.5*sin(p.z*6.+sin(p.x*7.)+p.y*4.);
    // Deep teal tissue warms toward a glowing, out-of-focus nucleus side.
    float warm=pow(max(dot(p,normalize(vec3(.55,.35,-.75))),0.),2.);
    float cool=pow(max(dot(p,normalize(vec3(-.6,-.2,.7))),0.),2.);
    vec3 deep=mix(vec3(.008,.03,.042),vec3(.03,.085,.078),cloud);
    deep+=vec3(.09,.035,.05)*warm+vec3(.02,.03,.08)*cool;
    // A network of neighbouring cells, their walls glowing faintly.
    vec3 tiles=voronoi(p*7.+vec3(0.,t*.02,0.));
    float wall=1.-smoothstep(.0,.06,tiles.y);
    float vein=pow(.5+.5*sin(flow*5.+tiles.x*9.),18.);
    vec3 wall_color=mix(vec3(.07,.2,.17),vec3(.24,.11,.15),warm);
    // Ridges ripple slowly through the membrane.
    float ridges=pow(.5+.5*sin(flow*3.+p.y*9.+t*.15),12.);
    float pulse=.94+.06*sin(t*.35+flow);
    // Floating out-of-focus vesicles: soft round bokeh discs.
    vec3 bokeh=voronoi(p*13.+vec3(t*.01,0.,-t*.015));
    float glow=smoothstep(.2,.06,bokeh.x)*step(.7,bokeh.z);
    vec3 color=deep+wall_color*wall*.55+wall_color*vein*.18+vec3(.028,.065,.05)*ridges;
    color+=mix(vec3(.12,.3,.26),vec3(.36,.2,.24),warm)*glow*.35;
    ALBEDO=color*pulse;
}
