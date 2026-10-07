shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled,shadows_disabled;
// Glowing jellyfish: a pulsing translucent bell trailing long tentacles.
// UV.x 0 marks the bell (UV.y from crown to rim), 1 the tentacles (UV.y to tip).
uniform float race_time=0.;
varying float phase;
varying vec3 local;
void vertex(){
    phase=float(INSTANCE_ID)*1.37;
    local=VERTEX;
    float pulse=pow(.5+.5*sin(race_time*1.5+phase),2.);
    if(UV.x<.5){
        VERTEX.xz*=1.-.17*pulse*UV.y;
        VERTEX.y*=1.+.12*pulse;
    }else{
        float s=UV.y;
        VERTEX.x+=sin(race_time*1.1+phase+s*5.)*.2*s;
        VERTEX.z+=cos(race_time*.9+phase*1.7+s*4.)*.2*s;
        VERTEX.xz*=1.-.1*pulse*(1.-s);
        VERTEX.y+=.12*pulse*s;
    }
}
void fragment(){
    vec3 tint=COLOR.rgb;
    float glow;
    if(UV.x<.5){
        float facing=abs(dot(NORMAL,VIEW));
        float fresnel=pow(1.-facing,2.);
        // Four-leaf gonads glowing through the bell, and a bright beaded rim.
        float r=length(local.xz)/.5;
        float a=atan(local.z,local.x);
        float organs=1.-smoothstep(.0,.07,abs(r-.32-.1*cos(4.*a)));
        float beads=smoothstep(.85,.98,UV.y)*(.6+.4*sin(a*24.));
        glow=.07+fresnel*.55+organs*.45+beads*.8;
    }else{
        glow=(.55*(1.-UV.y)+.1)*(.7+.3*sin(UV.y*40.-race_time*3.+phase));
    }
    ALBEDO=tint*1.4;
    ALPHA=clamp(glow,0.,1.);
}
