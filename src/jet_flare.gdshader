shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 jet_tint : source_color = vec3(.1,.6,1.);
uniform float power=0.;
uniform float boost_amount=0.;
varying vec2 source_uv;
varying float source_distance;
varying float facing;
void vertex(){
    vec4 center=VIEW_MATRIX*MODEL_MATRIX*vec4(0.,0.,0.,1.);
    vec4 clip=PROJECTION_MATRIX*center;
    source_uv=clip.xy/clip.w*.5+.5;
    source_distance=-center.z;
    vec3 eye=normalize(CAMERA_POSITION_WORLD-MODEL_MATRIX[3].xyz);
    facing=smoothstep(.05,.75,dot(eye,-normalize(MODEL_MATRIX[2].xyz)));
    // Camera-facing optics stay horizontal in every split-screen view and roll.
    MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment(){
    if(min(source_uv.x,source_uv.y)<0. || max(source_uv.x,source_uv.y)>1.){discard;}
    float depth=textureLod(depth_texture,source_uv,0.).r;
    if(CLIP_SPACE_FAR<0.){depth=depth*2.-1.;}
    vec4 scene=INV_PROJECTION_MATRIX*vec4(source_uv*2.-1.,depth,1.);
    // A nozzle-sized tolerance admits its own bright core, but hides optics
    // behind hulls and scenery instead of letting the large quad leak around it.
    float visibility=smoothstep(-.65,-.15,-scene.z/scene.w-source_distance);
    vec2 p=(UV*2.-1.)*vec2(1.,.30);
    float streak=exp(-abs(p.x)*4.)*exp(-p.y*p.y*11000.);
    float bloom=exp(-dot(p,p)*180.);
    float ring=exp(-pow((length(p)-.16)*75.,2.))*.035;
    float edge=1.-smoothstep(.72,1.,abs(p.x));
    ALBEDO=mix(jet_tint,vec3(.85,.97,1.),bloom*.7)*(1.+boost_amount*.6);
    ALPHA=(streak*.45+bloom*.24+ring)*edge*power*(.35+boost_amount*.65)*facing*visibility;
}
