// Sandstone stratigraphy shared by the canyon terrain and the loose rocks.
// Real canyon walls are a stack of formations tens of metres thick, each made of
// beds of uneven thickness: hard beds stand out as ledges, soft ones recede, dune
// sandstones carry tilted cross-bedding and dark varnish streaks hang from lips.
float strata_hash(float n){return fract(sin(n*127.1+.31)*43758.5453);}
float strata_hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float strata_noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(strata_hash2(i),strata_hash2(i+vec2(1,0)),f.x),mix(strata_hash2(i+vec2(0,1)),strata_hash2(i+vec2(1,1)),f.x),f.y);
}
float strata_noise1(float x){
    float i=floor(x),f=fract(x);f=f*f*(3.-2.*f);
    return mix(strata_hash(i),strata_hash(i+1.),f);
}
// Albedo in rgb, ledge relief in a: positive near a bed's top, negative under its lip.
vec4 sandstone(vec3 point,vec3 n,float distance_to_camera){
    float detail=1.-smoothstep(160.,700.,distance_to_camera);
    float steep=1.-abs(n.y);
    // Beds swell, pinch and dip gently across the landscape instead of lying flat.
    float h=point.y+strata_noise(point.xz*.0035)*26.+strata_noise(point.xz*.017)*6.+dot(point.xz,vec2(.011,.006));
    // Formations: thick units, each with its own colour and character.
    float unit_coordinate=h/68.+strata_noise1(h/91.)*.8;
    float unit=floor(unit_coordinate);
    float kind=strata_hash(unit*3.7+1.3);
    vec3 base;
    float bed_size;float crossbedded=0.;float varnish_strength;
    if(kind<.38){base=vec3(.60,.28,.15);bed_size=2.6;varnish_strength=.7;} // red cliff sandstone
    else if(kind<.72){base=vec3(.74,.43,.24);bed_size=9.;crossbedded=1.;varnish_strength=.5;} // orange dune sandstone
    else if(kind<.9){base=vec3(.52,.27,.16);bed_size=1.6;varnish_strength=.2;} // chocolate siltstone slope
    else {base=vec3(.78,.57,.38);bed_size=5.;varnish_strength=.35;} // pale caprock
    base*=.9+strata_hash(unit*9.1)*.2;
    // A soft seam between formations instead of a hard line.
    float unit_edge=fract(unit_coordinate);
    base*=mix(.86,1.,smoothstep(0.,.05,unit_edge)*smoothstep(1.,.97,unit_edge));
    // Beds of irregular thickness inside the formation.
    float bed_coordinate=h/bed_size+strata_noise1(h/(bed_size*3.3)+unit*7.)*1.4;
    float bed=floor(bed_coordinate);
    float within=fract(bed_coordinate);
    float bed_random=strata_hash(bed*1.73+unit*13.1);
    vec3 color=base*mix(1.,.86+bed_random*.28,detail*.85+.15);
    // Hard beds form ledges: lit tops, a shadowed lip and a pale weathered rind.
    float hard=step(.58,bed_random)*(1.-crossbedded*.6);
    float lip=1.-smoothstep(0.,.14,within);
    color*=1.-hard*lip*.32*detail*steep;
    color=mix(color,color*1.12+vec3(.03,.02,.01),hard*smoothstep(.75,1.,within)*.5*detail);
    // Tilted cross-bedding inside dune sandstones, a different angle per set.
    if(crossbedded>.5){
        float angle=strata_hash(bed*5.3+unit)*6.2832;
        vec2 dip=vec2(cos(angle),sin(angle))*(.25+strata_hash(bed*2.1)*.35);
        float lamina=fract(h*.9+dot(point.xz,dip)*.9+strata_noise(point.xz*.08)*.8);
        color*=1.-smoothstep(.8,1.,lamina)*.12*detail*steep;
    }
    // Desert varnish hangs from ledges in long, uneven streaks.
    vec2 streak_space=vec2((point.x*.71-point.z*.71)*.21+(point.x+point.z)*.05,h*.012);
    float streak=strata_noise(streak_space)*.65+strata_noise(streak_space*vec2(2.7,1.3)+4.)*.35;
    float hang=smoothstep(.0,.55,1.-within)*.4+.6;
    float varnish=smoothstep(.5,.78,streak)*varnish_strength*hang*steep;
    color=mix(color,vec3(.22,.11,.07),varnish*mix(.55,1.,detail));
    // Mottled weathering and pitting breaks up every surface.
    vec2 face=vec2(point.x+point.z*.6,point.y);
    float mottle=strata_noise(face*.11)*.6+strata_noise(face*.43)*.4;
    color*=.86+mottle*.26;
    float pits=smoothstep(.78,.92,strata_noise(face*1.3+bed))*detail*steep;
    color*=1.-pits*.25;
    float relief=(within-.5)*mix(.18,.55,hard)*detail*steep;
    return vec4(color,relief);
}
