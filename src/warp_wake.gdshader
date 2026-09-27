shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength=0.;
uniform float race_time=0.;
void fragment(){
    // Narrow, soft filaments: plenty of empty space around the exposed hull.
    float crossfade=pow(max(0.,1.-abs(UV.x*2.-1.)),2.8);
    float ends=smoothstep(0.,.10,UV.y)*pow(1.-UV.y,1.6);
    float pulse=pow(.5+.5*sin(UV.y*15.-race_time*11.+COLOR.r*23.),5.);
    float hairline=pow(max(0.,1.-abs(UV.x*2.-1.)),12.);
    vec3 tint=mix(vec3(.28,.8,1.),vec3(.7,.65,1.),COLOR.r*.45);
    ALBEDO=mix(tint,vec3(.85,.98,1.),hairline)*2.2;
    ALPHA=strength*ends*crossfade*(.10+pulse*.55);
}
