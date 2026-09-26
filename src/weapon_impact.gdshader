shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform float age=0.;
void fragment(){
    float soft=pow(max(dot(normalize(NORMAL),normalize(VIEW)),0.),1.8);
    float ripple=.7+.3*sin(UV.x*39.+sin(UV.y*27.)*2.+age*7.);
    vec3 fire=mix(vec3(1.,.85,.38),vec3(1.,.15,.025),age);
    ALBEDO=fire;EMISSION=fire*2.;
    ALPHA=soft*ripple*(1.-age)*.9;
}
