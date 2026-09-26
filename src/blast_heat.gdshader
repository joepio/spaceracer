// Adapted from Growing Guns' expanding heat shell; see third_party/growing-guns.
shader_type spatial;
render_mode unshaded,cull_back,depth_draw_never,fog_disabled;
uniform sampler2D screen_tex : hint_screen_texture,filter_linear;
uniform sampler2D depth_tex : hint_depth_texture,filter_nearest;
uniform float falloff=1.;
void fragment(){
    float fresnel=pow(1.-abs(dot(normalize(VIEW),normalize(NORMAL))),1.1);
    float weight=.38+.62*fresnel;
    vec2 offset=normalize(NORMAL).xy*.018*weight*falloff;
    vec2 zoom=(SCREEN_UV-vec2(.5))*.008*weight*falloff;
    vec2 uv=clamp(SCREEN_UV-zoom+offset,vec2(.001),vec2(.999));
    float depth=texture(depth_tex,uv).r;
    if(CLIP_SPACE_FAR<0.){depth=depth*2.-1.;}
    vec4 scene=INV_PROJECTION_MATRIX*vec4(uv*2.-1.,depth,1.);
    float behind=smoothstep(0.,1.6,VERTEX.z-scene.z/scene.w);
    ALBEDO=texture(screen_tex,uv).rgb;
    ALPHA=weight*falloff*behind;
}
