shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
varying vec4 fire_color;
void vertex(){fire_color=COLOR;}
void fragment(){
    float soft=pow(max(dot(normalize(NORMAL),normalize(VIEW)),0.),2.5);
    ALBEDO=fire_color.rgb;
    EMISSION=fire_color.rgb*2.;
    ALPHA=fire_color.a*soft*.8;
}
