shader_type spatial;
render_mode unshaded,cull_front;
uniform float race_time=0.;
varying vec3 cell_point;
void vertex(){cell_point=VERTEX*2.;}
void fragment(){
    vec3 p=normalize(cell_point);
    float flow=sin(p.x*11.+sin(p.z*8.)*1.8)+sin(p.y*17.+p.z*9.+sin(p.x*12.));
    float ridges=pow(.5+.5*sin(flow*3.+p.y*9.),12.);
    float cloud=.5+.5*sin(p.z*6.+sin(p.x*7.)+p.y*4.);
    float pulse=.96+.04*sin(race_time*.3+flow);
    vec3 deep=mix(vec3(.009,.028,.04),vec3(.035,.082,.073),cloud);
    ALBEDO=(deep+vec3(.028,.065,.05)*ridges)*pulse;
}
