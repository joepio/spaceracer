shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;
// Adapted radial/longitudinal falloff from Growing Guns laser_tracer.gdshader.
uniform vec3 head_world;
uniform vec3 tail_world;
uniform float beam_radius=.025;
uniform float strength=0.;
void vertex(){
    vec3 segment=tail_world-head_world;
    vec3 direction=segment/max(length(segment),.0001);
    vec3 center=mix(head_world,tail_world,UV.y);
    vec3 across=cross(direction,CAMERA_POSITION_WORLD-center);
    if(length(across)<.001){across=INV_VIEW_MATRIX[0].xyz;}
    vec3 beam_position=center+normalize(across)*(UV.x*2.-1.)*beam_radius*4.;
    VERTEX=(VIEW_MATRIX*vec4(beam_position,1.)).xyz;
}
void fragment(){
    // Ribbon coordinates avoid precision loss far from the world origin.
    float distance_along=UV.y;
    float radial=abs(UV.x*2.-1.)*4.;
    float core=exp(-1.15*radial*radial);
    float halo=exp(-.24*radial*radial)*(1.-smoothstep(3.,4.,radial));
    float contact=smoothstep(.94,1.,distance_along);
    // Faint airborne scattering; the actual contact carries the white radiance.
    ALBEDO=mix(vec3(.9,.18,.22),vec3(1.,.97,.94),contact)*(2.0+contact*4.);
    ALPHA=(core+halo*.08)*strength*(.30+contact*.32);
}
