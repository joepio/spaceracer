shader_type spatial;
render_mode unshaded;
uniform sampler2D artwork : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float panel=0.;
void fragment(){
    vec2 uv=vec2((panel+clamp(UV.x,.003,.997))*.25,UV.y);
    vec3 art=texture(artwork,uv).rgb;
    ALBEDO=art*2.2;
    // Fine LED scan structure disappears cleanly with distance.
    float scan=1.-.045*sin(UV.y*1100.);
    ALBEDO*=scan;
}
