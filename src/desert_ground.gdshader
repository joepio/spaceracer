shader_type spatial;
// Wind-rippled sand on the dunes; banded sandstone on every steep face.
uniform float floor_level=0.;
uniform vec3 sun_direction=vec3(.4,.5,.2);
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
    vec3 n=normalize(mat3(INV_VIEW_MATRIX)*NORMAL);
    float near=1.-smoothstep(120.,700.,length(VERTEX));
    float patch=noise(world.xz*.006)*.6+noise(world.xz*.031)*.4;
    // Ripples run across the prevailing wind and bend with the dune noise.
    float phase=dot(world.xz,vec2(.82,.57))*.55+noise(world.xz*.02)*7.;
    float ripple=sin(phase)*.5+.5;
    vec3 sand=mix(vec3(.62,.39,.20),vec3(.86,.62,.36),patch);
    sand=mix(sand,sand*vec3(1.08,1.04,.98),pow(ripple,3.)*near);
    sand*=.92+noise(world.xz*.9)*.16*near;
    // Sandstone strata: warped horizontal bands with darker desert varnish.
    float height=world.y-floor_level+noise(world.xz*.008)*16.;
    float band=sin(height*.22)*.5+.5;
    band=mix(band,.5,smoothstep(900.,2600.,length(VERTEX)));
    // Fine laminations fade out before they can alias into moire.
    float fine=(sin(height*1.1+noise(world.xz*.05)*3.)*.5+.5)*(1.-smoothstep(150.,600.,length(VERTEX)));
    vec3 stone=mix(vec3(.48,.22,.12),vec3(.72,.42,.24),band);
    stone=mix(stone,vec3(.86,.58,.34),smoothstep(.75,1.,fine)*.45);
    stone=mix(stone,vec3(.30,.15,.09),smoothstep(.55,.9,noise(vec2(world.x+world.z,world.y*.6)*.09))*.35);
    float rock=1.-smoothstep(.58,.84,n.y);
    // Sand drifts settle on terraces; the wash floor reads slightly darker.
    vec3 color=mix(sand,stone,rock);
    color*=mix(.78,1.,smoothstep(0.,30.,world.y-floor_level));
    ALBEDO=color;
    // Fine ripple relief catches the low sun near the camera.
    float slope=cos(phase)*.22*near*(1.-rock);
    vec3 bent=normalize(n+vec3(.82,0.,.57)*slope);
    NORMAL=normalize(mat3(VIEW_MATRIX)*bent);
    ROUGHNESS=mix(.97,.86,rock);
    SPECULAR=.18;
}
