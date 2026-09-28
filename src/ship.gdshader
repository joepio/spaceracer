shader_type spatial;
render_mode cull_disabled;
uniform vec3 tint : source_color =vec3(.2,1.,.8);
uniform float wrecked=0.;
uniform float damage : hint_range(0.,1.)=0.;
uniform bool wear_enabled=true;
uniform vec3 wear_offset=vec3(0.);
uniform float rebuild_progress=1.;
uniform mat4 rebuild_inverse;
uniform sampler2D wear_mask : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pilot_face : source_color, filter_nearest_mipmap, repeat_disable;
uniform bool has_face=false;
instance uniform bool face_surface=false;
instance uniform float face_side=1.;
instance uniform int marking_style=0;
uniform vec3 marking_tint : source_color=vec3(.898,.867,.816);
varying vec3 local_normal;
varying vec3 local_position;
varying float rebuild_height;
void vertex(){
    local_position=VERTEX;local_normal=NORMAL;
    rebuild_height=(rebuild_inverse*MODEL_MATRIX*vec4(VERTEX,1.)).y;
}
void fragment(){
    if(rebuild_progress<1. && rebuild_height>mix(-1.,2.6,rebuild_progress)){discard;}
    float panel_distance=abs(fract((local_position.z+.6)*.4)-.5);
    float aa=max(fwidth(panel_distance),.001);
    float seam=1.-smoothstep(.002,.002+aa,panel_distance);
    // Painted livery lives in the opaque hull pass: no decal geometry, gaps,
    // z-fighting or detached trim when the aerodynamic surfaces articulate.
    float marking_distance=100.;
    if(marking_style==1 && local_normal.y>.15){
        float t=clamp((local_position.z-2.15)/2.7,0.,1.);
        marking_distance=max(abs(abs(local_position.x)-mix(.54,.16,t))-mix(.085,.025,t),
                             max(2.15-local_position.z,local_position.z-4.85));
    }else if(marking_style==2){
        // Loft UV.x follows the cross-section, so this hugs the shoulder even
        // where the engine pod narrows. UV.y remains the authored longitudinal UV.
        float shoulder=face_side<0. ? .20 : .50;
        marking_distance=max((abs(UV.x-shoulder)-.014)*8.,
                             max(-1.55-local_position.z,local_position.z-2.2));
    }else if(marking_style==3 && local_normal.y>.5){
        float t=clamp((-local_position.z-.45)/1.3,0.,1.);
        marking_distance=max(abs(abs(local_position.x)-mix(3.22,4.09,t))-mix(.23,.36,t),
                             max(local_position.z+.45,-1.75-local_position.z));
    }else if(marking_style==4 && abs(local_normal.x)>.35){
        float t=clamp(local_position.y/1.32,0.,1.);
        marking_distance=max(abs(local_position.z-mix(-.38,-.22,t))-.09,
                             max(.07-local_position.y,local_position.y-1.26));
    }
    // Bound the derivative at hard-normal/UV seams so a neighbouring face
    // cannot smear white paint onto an otherwise unmarked silhouette edge.
    float marking_aa=clamp(fwidth(marking_distance),.001,.025);
    float marking=1.-smoothstep(-marking_aa,marking_aa,marking_distance);
    vec3 pigment=mix(tint,marking_tint,marking);
    vec3 paint=mix(pigment*.52,pigment,smoothstep(-.3,.3,local_position.y));
    ALBEDO=paint*(1.-seam*.5);
    METALLIC=.32;
    ROUGHNESS=mix(.31,.43,seam);
    if(has_face && face_surface){
        // Opaque paint projection onto the two outer hull flanks. Separate
        // orientation per side keeps the face upright and facing the nose.
        vec2 uv=vec2(.5+(local_position.z-.65)*face_side/.9,
                     .5+(.24-local_position.y)/.9);
        float flank=smoothstep(.28,.48,abs(normalize(local_normal).x))*step(.05,local_position.x*face_side);
        if(all(greaterThanEqual(uv,vec2(0.))) && all(lessThanEqual(uv,vec2(1.)))){
            vec4 face=texture(pilot_face,uv);
            float ink=face.a*flank*(1.-wrecked);
            ALBEDO=mix(ALBEDO,face.rgb,ink);
            METALLIC=mix(METALLIC,.05,ink);
            ROUGHNESS=mix(ROUGHNESS,.42,ink);
        }
    }
    SPECULAR=.5;
    CLEARCOAT=.55;
    CLEARCOAT_ROUGHNESS=.26;
    if(wear_enabled){
        // One shared baked mask; triplanar mapping keeps vertical fins and hull
        // flanks as sharp as the wings without changing their authored UVs.
        vec3 weights=pow(abs(normalize(local_normal)),vec3(6.));
        weights/=max(.001,weights.x+weights.y+weights.z);
        vec3 at=local_position*.38+wear_offset;
        vec3 mask=texture(wear_mask,at.yz).rgb*weights.x
                 +texture(wear_mask,at.xz).rgb*weights.y
                 +texture(wear_mask,at.xy).rgb*weights.z;
        float amount=clamp(damage,0.,1.);
        float aa=max(fwidth(mask.r),.015);
        float threshold=.11+amount*.31;
        float chip=1.-smoothstep(threshold-aa,threshold+aa,mask.r);
        float rim=(1.-smoothstep(threshold+.015-aa,threshold+.045+aa,mask.r))-chip;
        float scratch=mask.g*(.13+amount*.87);
        float metal=max(chip,scratch*.85);
        float dirt=smoothstep(.40,.78,mask.b)*(.09+amount*.24);
        float rear_heat=1.-smoothstep(-2.3,.8,local_position.z);
        float scorch=smoothstep(.55,1.,amount)*smoothstep(.35,.72,mask.b)*mix(.3,.95,rear_heat);
        ALBEDO*=1.-dirt;
        ALBEDO=mix(ALBEDO,vec3(.11,.12,.125),rim*.7);
        ALBEDO=mix(ALBEDO,vec3(.20,.22,.23),metal);
        ALBEDO=mix(ALBEDO,vec3(.028,.024,.021),scorch);
        METALLIC=mix(METALLIC,.82,metal)*(1.-scorch*.85);
        ROUGHNESS=clamp(ROUGHNESS+amount*.12+dirt*.8+scratch*.20+scorch*.42+chip*.22,.28,.91);
        CLEARCOAT*=(1.-max(metal,scorch))*(1.-amount*.6);
    }
    ALBEDO=mix(ALBEDO,vec3(.018,.016,.015),wrecked);
}
