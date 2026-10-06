shader_type spatial;
// Shared sandstone for hoodoos, boulders and arches. Vertex color carries the
// authored tint; world-space strata keep neighbouring rocks geologically aligned.
uniform bool vegetation=false;
varying vec3 world;
varying vec3 world_normal;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){
    world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);
}
void fragment(){
    vec3 n=normalize(world_normal);
    if(vegetation){
        // Saguaro ribs: vertical grooves with pale spines catching the sun.
        float ribs=sin(atan(n.x,n.z)*12.)*.5+.5;
        ALBEDO=COLOR.rgb*(.72+ribs*.38)*(.9+noise(world.xz*2.+world.y)*.2);
        ROUGHNESS=.75;
        SPECULAR=.3;
    }else{
        float wobble=noise(world.xz*.05)*5.+noise(world.xz*.6)*.6;
        float band=sin((world.y+wobble)*.55)*.5+.5;
        float fine=(sin((world.y+wobble)*1.6)*.5+.5)*(1.-smoothstep(120.,500.,length(VERTEX)));
        vec3 stone=mix(vec3(.50,.24,.13),vec3(.76,.46,.26),band);
        stone=mix(stone,vec3(.90,.66,.42),smoothstep(.8,1.,fine)*.4);
        // Dark varnish streaks run down the vertical faces.
        float varnish=smoothstep(.5,.85,noise(vec2((world.x+world.z)*.25,world.y*.02)));
        stone=mix(stone,vec3(.26,.13,.08),varnish*.45*(1.-abs(n.y)));
        // Wind-blown sand collects on every upward face.
        stone=mix(stone,vec3(.84,.60,.35),smoothstep(.72,.95,n.y)*.8);
        ALBEDO=stone*COLOR.rgb*(.9+noise(world.xz*1.3+world.y*.7)*.2);
        ROUGHNESS=.93;
        SPECULAR=.15;
    }
}
