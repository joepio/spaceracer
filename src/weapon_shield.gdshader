shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform float strength=0.;
uniform float race_time=0.;
void fragment(){
    float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.5);
    float stripes=smoothstep(.65,.9,sin(UV.y*110.+race_time*8.));
    ALBEDO=vec3(.1,.8,1.)*2.;
    ALPHA=strength*(rim*.75+stripes*.1);
}
