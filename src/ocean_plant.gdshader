shader_type spatial;
render_mode cull_disabled;
// Giant reef flora swaying in the current. kind: 0 kelp, 1 lantern weed,
// 2 sea fan, 3 tube sponges. Vertex alpha marks the bioluminescent parts.
uniform int kind=0;
uniform float race_time=0.;
uniform vec3 glow_color=vec3(.3,1.,.9);
varying float phase;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){
    phase=dot(MODEL_MATRIX[3].xz,vec2(.013,.021));
    float h=max(VERTEX.y,0.);
    float amount=kind==0?.07:(kind==1?.025:(kind==2?.02:0.));
    float bend=pow(h,1.6)*amount;
    VERTEX.x+=sin(race_time*.55+phase+h*2.6)*bend;
    VERTEX.z+=cos(race_time*.41+phase*1.3+h*1.9)*bend*.7;
}
void fragment(){
    vec3 color=COLOR.rgb;
    ROUGHNESS=.65;
    SPECULAR=.3;
    if(kind==0){
        // Golden kelp: translucent where the light from above shines through.
        float veins=.85+.15*sin(UV.x*60.);
        ALBEDO=color*veins;
        BACKLIGHT=color*vec3(.9,1.,.5)*.7;
    }else if(kind==1){
        float pulse=.65+.35*sin(race_time*1.4+phase*7.+UV.y*3.);
        ALBEDO=mix(color,color*.4,COLOR.a);
        EMISSION=COLOR.rgb*COLOR.a*pulse*2.4;
        BACKLIGHT=color*.4;
    }else if(kind==2){
        // A lattice of branching ribs spread across a flat fan.
        vec2 p=UV-vec2(.5,0.);
        float r=length(p)*2.;
        float a=atan(p.x,p.y);
        float outline=1.-smoothstep(.86,.9,r+noise(vec2(a*6.,1.))*.12);
        float spokes=abs(sin(a*(18.+floor(r*3.)*9.)+noise(p*8.)*2.));
        float rings=abs(sin(r*40.+noise(p*12.)*3.));
        float lattice=max(1.-smoothstep(.2,.45,spokes),1.-smoothstep(.15,.4,rings));
        if(UV.y<0.)lattice=1.;
        ALPHA=outline*lattice;
        ALPHA_SCISSOR_THRESHOLD=.5;
        ALBEDO=color*(.75+r*.35);
        BACKLIGHT=color*.5;
    }else{
        float rim=COLOR.a;
        ALBEDO=color*(.8+noise(UV*vec2(8.,30.))*.3)*(1.-rim*.5);
        EMISSION=glow_color*rim*(.7+.3*sin(race_time*.9+phase*5.+UV.x*6.))*1.6;
    }
}
