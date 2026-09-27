shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform float curvature=.16;
uniform vec2 texel=vec2(.00052,.00093);
uniform float pixel_scale=2.4;
uniform float damage=0.;
uniform bool quiet=false;
uniform float online=1.;
uniform sampler2D instruments : filter_linear, repeat_disable;

vec4 instrument(vec2 uv){
    if(any(lessThan(uv,vec2(0.)))||any(greaterThan(uv,vec2(1.)))){return vec4(0.);}
    return texture(instruments,uv);
}
void fragment(){
    vec2 p=UV-.5;
    vec2 at=.5+p*(1.+curvature*dot(p,p)*4.);
    vec4 core=instrument(at);
    vec2 px=texel*pixel_scale;
    // A restrained halo from the instruments themselves, never from the scene.
    vec4 glow=(instrument(at+vec2(px.x*1.6,0.))+instrument(at-vec2(px.x*1.6,0.))
             +instrument(at+vec2(0.,px.y*1.6))+instrument(at-vec2(0.,px.y*1.6)))*.25;
    vec3 halo=(instrument(at+px*3.5).rgb+instrument(at-px*3.5).rgb
              +instrument(at+px*vec2(3.5,-3.5)).rgb+instrument(at+px*vec2(-3.5,3.5)).rgb)*.25;
    // Very slight lens ghosting, strongest at the periphery, with a sharp core.
    vec2 ghost_offset=p*px*2.;
    vec3 ghost=instrument(at+ghost_offset).rgb*vec3(.08,.18,.23);
    vec3 radiance=core.rgb*.70+glow.rgb*.14+halo*.07+ghost*.18;
    float rim=smoothstep(.66,1.20,length(p*vec2(1.75,1.85)));
    float lower=smoothstep(.55,1.,UV.y);
    float shade=(rim*.15+lower*rim*.09)*(quiet?.35:1.);
    // Light is added on top; only a faint smoked visor film attenuates the world.
    // The local undercoat keeps projection legible against the daytime sky.
    float undercoat=clamp(glow.a*.20+core.a*.08,0.,.25);
    COLOR=vec4(radiance*online+vec3(.008,.023,.032)*shade+vec3(.22,.018,.025)*rim*damage*online,
               min(.38,shade+undercoat*online));
}
