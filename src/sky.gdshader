shader_type sky;
uniform vec3 top_color=vec3(.0024,.004,.008);
uniform vec3 horizon_color=vec3(.0075,.013,.024);
void sky(){
    // A broad, dim night gradient; no sinusoidal horizon band or luminous clouds.
    float elevation=clamp(normalize(EYEDIR).y,0.,1.);
    float horizon=pow(1.-elevation,3.);
    COLOR=mix(top_color,horizon_color,horizon);
}
