// Shared by the seafloor and loose reef rocks: dark volcanic rock crusted with
// sponges, coral and algae, and the dancing caustics of the surface far above.
float reef_hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float reef_hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float reef_noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(reef_hash2(i),reef_hash2(i+vec2(1,0)),f.x),mix(reef_hash2(i+vec2(0,1)),reef_hash2(i+vec2(1,1)),f.x),f.y);
}
// Light focused by surface waves: bright, wobbling cells of light.
float caustic(vec2 uv,float t){
    vec2 p=mod(uv*6.28318,6.28318)-250.;
    vec2 i=p;
    float c=1.;
    for(int n=0;n<4;n++){
        float tt=t*(1.-(3.5/float(n+1)));
        i=p+vec2(cos(tt-i.x)+sin(tt+i.y),sin(tt-i.y)+cos(tt+i.x));
        c+=1./length(vec2(p.x/(sin(i.x+tt)/.005),p.y/(cos(i.y+tt)/.005)));
    }
    c/=4.;
    c=1.17-pow(c,1.4);
    return clamp(pow(abs(c),8.),0.,2.);
}
vec3 reef_rock(vec3 point,vec3 n,float distance_to_camera){
    float detail=1.-smoothstep(150.,650.,distance_to_camera);
    vec2 face=vec2(point.x+point.z*.7,point.y+point.z*.3);
    float mottle=reef_noise(point.xz*.04+point.y*.03)*.5+reef_noise(face*.19)*.3+reef_noise(face*.8)*.2*detail;
    vec3 rock=mix(vec3(.12,.13,.13),vec3(.3,.29,.26),mottle);
    // Encrusting life in soft, organic patches; hues drift slowly across the reef.
    float hue=reef_noise(point.xz*.006+point.y*.004);
    vec3 colony=mix(vec3(.62,.3,.16),vec3(.42,.22,.42),smoothstep(.3,.7,hue));
    colony=mix(colony,vec3(.68,.58,.3),smoothstep(.65,.9,reef_noise(face*.03+7.)));
    float blobs=reef_noise(face*.12)*.55+reef_noise(face*.37+3.)*.3+reef_noise(face*1.4)*.15*detail;
    float cover=smoothstep(.56,.72,blobs);
    float knobs=reef_noise(face*3.1)*detail;
    colony*=.7+knobs*.45;
    rock=mix(rock,colony,cover*.7);
    // Small bright polyps speckle the crust up close.
    float polyps=smoothstep(.8,.9,reef_noise(face*6.))*detail*cover;
    rock=mix(rock,vec3(.95,.75,.65),polyps*.5);
    // Soft green algae carpets the upward faces.
    float algae=smoothstep(.5,.85,n.y)*smoothstep(.35,.6,reef_noise(point.xz*.09));
    rock=mix(rock,vec3(.17,.3,.16)*(.8+mottle*.4),algae*.7);
    return rock;
}
