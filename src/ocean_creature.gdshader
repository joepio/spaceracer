shader_type spatial;
render_mode cull_disabled;
// Sea creatures animated from the race clock. kind: 0 fish, 1 manta ray,
// 2 octopus mantle, 3 octopus arm (curled on the GPU from INSTANCE_CUSTOM).
uniform int kind=0;
uniform float race_time=0.;
varying float phase;
varying float inner_side;
varying vec3 local;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
// Arm direction from vertical at arc length s: a base angle, a curl that
// tightens toward the tip, and a travelling wave.
float arm_angle(float s,vec4 c){
    return c.y+(c.z-c.y)*s*s+c.w*sin(race_time*.75+c.x+s*5.)*s;
}
void vertex(){
    phase=float(INSTANCE_ID)*1.37+dot(MODEL_MATRIX[3].xz,vec2(.011,.017));
    local=VERTEX;
    inner_side=0.;
    if(kind==0){
        // Tail-driven swimming: the wave grows toward the tail.
        float tail=smoothstep(-.25,.5,VERTEX.z);
        VERTEX.x+=sin(race_time*10.+phase-VERTEX.z*6.)*.09*tail;
    }else if(kind==1){
        float span=abs(VERTEX.x);
        VERTEX.y+=sin(race_time*.95+phase-span*1.3)*pow(span,1.5)*.26;
    }else if(kind==2){
        phase=dot(MODEL_MATRIX[3].xz,vec2(.011,.017));
        VERTEX*=1.+.035*sin(race_time*.8+phase)*smoothstep(.4,1.2,VERTEX.y);
    }else{
        vec4 c=INSTANCE_CUSTOM;
        float s=UV.y;
        float around=UV.x*6.28318;
        vec2 p=vec2(0.);
        const int STEPS=16;
        for(int i=0;i<STEPS;i++){
            float s0=float(i)/float(STEPS);
            float ds=clamp(s-s0,0.,1./float(STEPS));
            float theta=arm_angle(s0+ds*.5,c);
            p+=ds*vec2(sin(theta),cos(theta));
        }
        float theta=arm_angle(s,c);
        vec2 n2=vec2(cos(theta),-sin(theta));
        float radius=.05*(1.-s*.9)*(1.+.25*smoothstep(.1,0.,s));
        VERTEX=vec3(p.x+n2.x*cos(around)*radius,p.y+n2.y*cos(around)*radius,sin(around)*radius);
        NORMAL=normalize(vec3(n2*cos(around),sin(around)));
        inner_side=cos(around);
        local=vec3(s,around,0.);
        phase=c.x;
    }
}
void fragment(){
    vec3 color=COLOR.rgb;
    ROUGHNESS=.5;
    SPECULAR=.45;
    if(kind==0){
        // Iridescent scales flash as fish turn.
        ALBEDO=color;
        METALLIC=.3;
        ROUGHNESS=.35;
        // A faint sheen keeps schools readable through the blue haze.
        EMISSION=color*.12;
    }else if(kind==1){
        ALBEDO=color*(.85+noise(local.xz*9.)*.3);
        ROUGHNESS=.55;
    }else if(kind==2){
        // Chromatophores: slow waves of colour pass over warty skin.
        float warts=noise(local.xy*14.+local.z*9.);
        float wave=.5+.5*sin(local.y*6.-race_time*1.3+local.x*3.+phase);
        vec3 skin=mix(vec3(.5,.12,.08),vec3(.82,.32,.16),wave*.7+warts*.3);
        skin=mix(skin,vec3(.95,.62,.45),smoothstep(.75,.95,warts)*.5);
        if(COLOR.a>.5){
            // Golden eye with a dark horizontal slit pupil.
            float slit=1.-smoothstep(.03,.06,abs(UV.y-.5));
            skin=mix(vec3(.85,.62,.18),vec3(.02),slit);
            ROUGHNESS=.15;SPECULAR=.9;
        }
        ALBEDO=skin;
        float bumps=noise(local.xy*30.+local.z*20.)-.5;
        NORMAL=normalize(NORMAL+vec3(bumps*.25,bumps*.25,0.));
    }else{
        float s=local.x;
        float wave=.5+.5*sin(s*18.-race_time*1.3+phase);
        vec3 skin=mix(vec3(.5,.12,.08),vec3(.8,.3,.15),wave*.7+noise(vec2(s*60.,local.y*3.))*.3);
        // Two rows of pale suckers on the inside of each curl.
        float row=step(.35,inner_side);
        vec2 cell=vec2(fract(s*90./(1.-s*.85))-.5,(inner_side-.75)*3.);
        float sucker=1.-smoothstep(.25,.4,length(cell));
        float rim=smoothstep(.15,.25,length(cell))*sucker;
        skin=mix(skin,vec3(.98,.78,.66)*(1.-rim*.35),row*sucker*smoothstep(.98,.85,s));
        skin=mix(skin,vec3(.95,.7,.6),smoothstep(.2,.9,inner_side)*.35);
        ALBEDO=skin;
    }
}
