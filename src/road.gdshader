shader_type spatial;
render_mode cull_disabled;
uniform vec3 accent = vec3(.25,1.0,.85);
uniform vec3 secondary = vec3(1.,.2,.6);
uniform float race_time=0.;
void fragment() {
    float lateral=abs(UV.x);
    vec3 sector=mix(accent,secondary,COLOR.g);
    float shoulder=smoothstep(.75,.78,lateral);
    float edge=smoothstep(.975,.99,lateral);
    float lane=(1.-smoothstep(.004,.011,abs(lateral-.33)))*step(.40,fract(UV.y/32.));
    float panel=step(.976,fract(UV.y/9.));
    float side_panel=step(.91,fract(UV.x*12.));
    float rivet=step(.965,fract(UV.y/4.5))*step(.97,fract(UV.x*18.));
    vec3 base=mix(vec3(.045,.065,.095),vec3(.07,.095,.13),step(.5,fract(UV.y/18.)));
    base=mix(base,sector*.16,shoulder);
    base*=1.-panel*.5-side_panel*.10;
    float diagonal=step(.56,fract(UV.y/11.+lateral*3.))*shoulder*(1.-edge);
    vec3 light=sector*edge*.85+vec3(.28,.43,.58)*lane*.5+sector*diagonal*.12;
    float pulse=pow(max(0.,sin(UV.y*.045-race_time*3.)),16.);
    light+=secondary*pulse*shoulder*.32;
    if(COLOR.b>.5 && lateral>.65 && lateral<.96){
        float bar=step(.68,fract(UV.y/12.));
        base=mix(base,vec3(.55,.23,.025),bar);
        light+=vec3(1.,.4,.04)*bar*.55;
    }
    float zone=COLOR.r*2.;
    if(zone>.8 && zone<1.2 && UV.x<-.35){
        base=vec3(.025,.13,.10);
        light+=vec3(.08,.85,.4)*(.16+.38*step(.65,fract(UV.y/8.-race_time*.6)));
    }
    if(zone>1.8 && lateral<.35){
        float arrow=step(.65,fract((UV.y-lateral*24.)/14.));
        base=vec3(.24,.08,.015);
        light+=vec3(1.,.36,.025)*(.15+arrow*.9);
    }
    float start=(1.-step(9.,UV.y))*step(.5,fract(UV.x*12.+floor(UV.y/3.)*.5));
    ALBEDO=base+light*.2+vec3(start*.65)+vec3(rivet*.2);
    EMISSION=light*.65;
    METALLIC=.28;
    SPECULAR=.18;
    ROUGHNESS=.5;
}
