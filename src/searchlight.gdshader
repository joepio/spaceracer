shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// A soft volumetric-looking beam: bright core, feathered edges, fading upward.
uniform vec3 tint : source_color = vec3(.8,.88,1.);
void fragment(){
    float facing=abs(dot(normalize(NORMAL),normalize(VIEW)));
    float along=UV.y;
    float fade=pow(1.-along,1.6)*smoothstep(0.,.02,along);
    ALBEDO=tint*pow(facing,3.)*fade*.07;
}
