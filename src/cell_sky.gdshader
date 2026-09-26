shader_type sky;
uniform vec3 top_color=vec3(.015,.045,.055);
uniform vec3 horizon_color=vec3(.055,.105,.095);
void sky(){
    vec3 p=normalize(EYEDIR);
    float folds=.5+.5*sin(p.y*13.+sin(p.x*9.)+sin(p.z*8.));
    COLOR=mix(top_color,horizon_color,folds*.6+.2);
}
