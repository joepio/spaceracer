shader_type spatial;
render_mode cull_disabled;
uniform float race_time=0.;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
    float lateral=abs(UV.x);
    vec3 rail_color=mix(vec3(.32,.66,.78),vec3(.54,.35,.53),COLOR.g);
    float edge=smoothstep(.975,.99,lateral);
    float lane=(1.-smoothstep(.004,.011,abs(lateral-.33)))*step(.40,fract(UV.y/32.));
    float panel=step(.985,fract(UV.y/18.));
    float grain=noise(vec2(UV.x*95.,UV.y*.35));
    vec3 base=vec3(.13,.15,.18)*mix(.88,1.06,grain);
    base*=1.-panel*.18;
    vec3 light=rail_color*edge*.65+vec3(.30,.38,.44)*lane*.16;
    // Functional markings are small insets in dark asphalt, never full colored lanes.
    if(COLOR.b>.5 && lateral>.79 && lateral<.92){
        float bar=step(.78,fract(UV.y/12.));
        light+=vec3(.65,.31,.09)*bar*.35;
    }
    float zone=COLOR.r*2.;
    if(zone>.8 && zone<1.2 && UV.x<-.35){
        float outline=1.-smoothstep(.008,.019,min(abs(UV.x+.40),abs(UV.x+.89)));
        float dash=step(.82,fract(UV.y/16.-race_time*.28));
        light+=vec3(.18,.55,.40)*(outline*.28+dash*.045);
    }
    if(zone>1.8 && lateral<.30){
        float arrow=step(.87,fract((UV.y-lateral*24.)/18.));
        light+=vec3(.72,.43,.13)*arrow*.36;
    }
    float start=(1.-step(9.,UV.y))*step(.5,fract(UV.x*12.+floor(UV.y/3.)*.5));
    // Subtle broken reflections remain close to their visible rail source.
    // Avoid hue-interpolated billboard pools and unsourced streaks across the road.
    float grazing=pow(1.-max(dot(normalize(NORMAL),normalize(VIEW)),0.),2.);
    float rail_pool=exp(-pow((lateral-.96)*10.,2.));
    float streak=pow(noise(vec2(UV.x*76.,UV.y*.045)),3.);
    vec3 reflection=rail_color*rail_pool*streak*(.10+grazing*.25);
    ALBEDO=base+vec3(start*.34);
    EMISSION=light+reflection;
    METALLIC=.12;
    SPECULAR=.25;
    ROUGHNESS=mix(.38,.48,grain);
}
