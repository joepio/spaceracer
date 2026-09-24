shader_type spatial;
uniform sampler2D facade : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 tint;
varying float facade_weight;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);tint=COLOR.rgb;facade_weight=COLOR.a;}
void fragment(){
    float face=abs(world_normal.x)>.5 ? world_position.z : world_position.x;
    // World-space repeats keep windows the same scale on differently sized meshes.
    vec2 uv=vec2(face/(72.+tint.b*24.),-world_position.y/(112.+tint.g*40.));
    uv+=floor(tint.rg*12.)/12.;
    vec3 tex=texture(facade,uv).rgb;
    float wall=(1.-smoothstep(.4,.8,abs(world_normal.y)))*facade_weight;
    float brightness=dot(tex,vec3(.2126,.7152,.0722));
    float style=floor(tint.r*4.);
    float structure=1.;
    if(style<1.){structure=mix(.14,1.,smoothstep(.08,.13,fract(face/22.)));}
    else if(style<2.){structure=mix(.10,1.,smoothstep(.12,.18,fract(world_position.y/48.)));}
    else if(style<3.){structure=mix(.22,1.,smoothstep(.12,.2,fract(face/13.)));}
    float room=smoothstep(.11,.48,brightness)*wall*structure;
    float floor_band=floor(world_position.y/8.);
    float occupancy=.4+.6*step(.28,fract(sin(floor_band*17.17+tint.r*33.)*433.1));
    vec3 tone=mix(vec3(1.,.87,.70),vec3(.86,.94,1.),tint.g);
    ALBEDO=mix(vec3(.025,.033,.048),tex*.38*mix(vec3(.65,.78,.88),vec3(1.,.87,.74),tint.b)*structure,wall);
    float haze=exp(-length(VERTEX)*.00032);
    EMISSION=tex*tone*room*occupancy*1.05*haze;
    METALLIC=.62;
    ROUGHNESS=mix(.3,.44,room);
}
