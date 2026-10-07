shader_type spatial;
uniform float water_level=0.;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
    vec3 n=normalize(mat3(INV_VIEW_MATRIX)*NORMAL);
    float patch=noise(world.xz*.012)*.65+noise(world.xz*.043)*.35;
    float grain=(noise(world.xz*.38)-.5)*(1.-smoothstep(150.,900.,length(VERTEX)));
    vec3 grass=mix(vec3(.045,.095,.024),vec3(.13,.21,.045),patch);
    vec3 stone=mix(vec3(.095,.105,.087),vec3(.19,.18,.13),patch);
    float rock=1.-smoothstep(.68,.94,n.y);
    vec3 earth=mix(vec3(.095,.074,.037),vec3(.23,.20,.115),patch);
    float shore=1.-smoothstep(1.,9.,world.y-water_level);
    // Sunny clearings: lighter meadow grass with wildflowers near the camera.
    float meadow=smoothstep(.55,.8,noise(world.xz*.004+3.1))*(1.-rock)*(1.-shore);
    grass=mix(grass,mix(vec3(.14,.24,.05),vec3(.25,.33,.07),patch),meadow*.7);
    vec2 bloom_cell=floor(world.xz*.7);
    float bloom=hash(bloom_cell);
    float petal=smoothstep(.42,.12,length(fract(world.xz*.7)-.5-(vec2(hash(bloom_cell+5.3),hash(bloom_cell+9.1))-.5)*.5));
    float flowers=step(.86-meadow*.18,bloom)*petal*(1.-smoothstep(60.,260.,length(VERTEX)));
    vec3 blossom=bloom>.96?vec3(.85,.78,.95):(bloom>.92?vec3(.95,.78,.16):vec3(.62,.36,.85));
    // Moss collects in the crevices of the stone.
    stone=mix(stone,vec3(.08,.13,.04),smoothstep(.35,.7,noise(world.xz*.09))*.5);
    vec3 ground=mix(mix(grass,stone,rock),earth,shore)*(.94+grain*.22);
    ALBEDO=mix(ground,blossom,flowers*(1.-rock)*(1.-shore));
    ALBEDO*=mix(.63,1.,smoothstep(-1.,3.,world.y-water_level));
    ROUGHNESS=.95;
    SPECULAR=.12;
}
