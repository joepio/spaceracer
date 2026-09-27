void city_surface(sampler2D facade_texture,highp vec3 world_position,highp vec3 world_normal,vec3 tint,float weight,highp float distance_to_eye,out vec3 albedo,out vec3 emission){
    highp float face=abs(world_normal.x)>.5 ? world_position.z : world_position.x;
    // World-space repeats keep windows the same scale on differently sized meshes.
    highp vec2 uv=vec2(face/(56.+tint.b*20.),-world_position.y/(90.+tint.g*28.));
    uv+=floor(tint.rg*12.)/12.;
    vec3 tex=texture(facade_texture,uv).rgb;
    float wall=(1.-smoothstep(.4,.8,abs(world_normal.y)))*weight;
    float brightness=dot(tex,vec3(.2126,.7152,.0722));
    float style=floor(tint.r*4.);
    float structure=1.;
    if(style<1.){structure=mix(.14,1.,smoothstep(.08,.13,fract(face/22.)));}
    else if(style<2.){structure=mix(.10,1.,smoothstep(.12,.18,fract(world_position.y/48.)));}
    else if(style<3.){structure=mix(.22,1.,smoothstep(.12,.2,fract(face/13.)));}
    // Average subpixel facade bands/occupancy instead of letting them sparkle.
    float footprint=max(fwidth(face/7.),fwidth(world_position.y/8.));
    structure=mix(structure,.85,smoothstep(.5,2.,footprint));
    float room=smoothstep(.11,.48,brightness)*wall*structure;
    float floor_band=floor(world_position.y/8.);
    float occupancy=.16+.84*step(.24,fract(sin(floor_band*17.17+floor(face/7.)*3.73+tint.r*33.)*433.1));
    occupancy=mix(occupancy,.80,smoothstep(.35,1.5,footprint));
    vec3 tone=mix(vec3(1.,.64,.30),vec3(.76,.88,1.),tint.g*.65);
    albedo=mix(vec3(.075,.09,.115),tex*.52*mix(vec3(.65,.78,.88),vec3(1.,.87,.74),tint.b)*structure,wall);
    // Fog handles distance; source radiance must stay stable in GI captures.
    emission=tex*tone*room*occupancy*2.2;
}
