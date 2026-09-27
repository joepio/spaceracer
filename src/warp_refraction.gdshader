shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float strength=0.;
uniform float race_time=0.;
varying float distance_fade;
void vertex(){
    // A world-sized lens facing each individual split-screen camera.
    vec3 center=(VIEW_MATRIX*MODEL_MATRIX*vec4(0.,.8,-1.,1.)).xyz;
    distance_fade=smoothstep(9.,17.,-center.z)*(1.-smoothstep(400.,600.,-center.z));
    VERTEX=center+vec3((UV-.5)*vec2(23.,14.),0.);
    MODELVIEW_MATRIX=mat4(1.);
}
float scene_gap(vec2 at, float lens_z, mat4 inverse_projection){
    float depth=textureLod(depth_texture,at,0.).r;
    if(CLIP_SPACE_FAR<0.){depth=depth*2.-1.;}
    vec4 scene=inverse_projection*vec4(at*2.-1.,depth,1.);
    return lens_z-scene.z/scene.w;
}
void fragment(){
    vec2 local=(UV-.5)*2.;
    float radius=length(local);
    float envelope=1.-smoothstep(.32,1.,radius);
    float flow=sin(radius*17.-race_time*7.+local.x*2.);
    vec2 waves=vec2(sin(local.y*8.+race_time*3.1),cos(local.x*9.-race_time*2.7));
    // Refraction shrinks with distance; no tint, glow or visible shell surface.
    vec2 bend=(local*(.55+flow*.45)+waves*.16)*envelope*strength;
    bend*=PROJECTION_MATRIX[1][1]*.65/max(12.,-VERTEX.z);
    bend.x*=VIEWPORT_SIZE.y/VIEWPORT_SIZE.x;
    vec2 at=clamp(SCREEN_UV+bend,vec2(.001),vec2(.999));
    // Neither the original nor displaced sample may pull foreground geometry
    // into the lens. Road barriers, other cars and buildings stay in front.
    float behind=smoothstep(0.,1.2,min(scene_gap(SCREEN_UV,VERTEX.z,INV_PROJECTION_MATRIX),scene_gap(at,VERTEX.z,INV_PROJECTION_MATRIX)));
    ALBEDO=textureLod(screen_texture,at,0.).rgb;
    ALPHA=envelope*strength*distance_fade*.9*behind;
}
