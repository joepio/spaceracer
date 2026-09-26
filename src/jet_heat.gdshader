shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float race_time=0.;
uniform float power=0.;
uniform float boost_amount=0.;
uniform float trail_length=8.;
void vertex(){
    vec3 start=(VIEW_MATRIX*MODEL_MATRIX*vec4(0.,0.,0.,1.)).xyz;
    vec3 end=(VIEW_MATRIX*MODEL_MATRIX*vec4(0.,-.4,-trail_length,1.)).xyz;
    vec2 direction=end.xy/max(.1,-end.z)-start.xy/max(.1,-start.z);
    direction=length(direction)>.0001?normalize(direction):vec2(0.,1.);
    vec2 across=vec2(-direction.y,direction.x);
    // One ribbon per nozzle, spanning the real exhaust path in this camera.
    VERTEX=mix(start,end,UV.y)+vec3(across*(UV.x-.5)*(2.2+UV.y*2.),0.);
    MODELVIEW_MATRIX=mat4(1.);
}
void fragment(){
    float across=UV.x*2.-1.;
    float envelope=(1.-smoothstep(.35,1.,abs(across)))*smoothstep(0.,.10,UV.y)*(1.-smoothstep(.50,1.,UV.y));
    float time=race_time*9.;
    vec2 waves=vec2(sin(UV.y*36.-time+sin(UV.x*17.+time*.5)),cos(UV.x*25.+UV.y*19.-time*.8));
    waves+=.35*vec2(sin(UV.y*71.+time*1.3),sin(UV.x*43.-time));
    // Sub-pixel idle shimmer grows to a few pixels during boost at 1080p.
    vec2 shift=waves*envelope*power*(.00035+boost_amount*.00165);
    shift.x*=VIEWPORT_SIZE.y/VIEWPORT_SIZE.x;
    vec2 at=clamp(SCREEN_UV+shift,vec2(.001),vec2(.999));
    float depth=textureLod(depth_texture,at,0.).r;
    if(CLIP_SPACE_FAR<0.){depth=depth*2.-1.;}
    vec4 scene=INV_PROJECTION_MATRIX*vec4(at*2.-1.,depth,1.);
    float behind=smoothstep(0.,.6,-scene.z/scene.w+VERTEX.z);
    ALBEDO=textureLod(screen_texture,at,0.).rgb;
    ALPHA=envelope*power*.7*behind;
}
