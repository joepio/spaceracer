// Shared by mounted signs and the road's bounded reflection rays.
vec3 neon_sign_art(vec2 uv, float style, vec3 color){
    vec2 p=uv*2.-1.;
    float aa=max(fwidth(p.x),fwidth(p.y))*1.2+.003;
    float border=1.-smoothstep(.018,.018+aa,abs(max(abs(p.x),abs(p.y))-.90));
    vec2 emblem=vec2(p.x,p.y*.85+.16);
    float ink=0.;
    if(style<.5){
        float hex=max(abs(emblem.x)*.866+abs(emblem.y)*.5,abs(emblem.y));
        ink=1.-smoothstep(.032,.032+aa,abs(hex-.48));
        ink=max(ink,(1.-smoothstep(.035,.035+aa,abs(emblem.x+emblem.y*.45)))*(1.-step(.32,abs(emblem.y))));
    }else if(style<1.5){
        float wing=abs(emblem.y+abs(emblem.x)*.65);
        ink=(1.-smoothstep(.035,.035+aa,abs(wing-.22)))*(1.-step(.66,abs(emblem.x)));
    }else{
        float ring=abs(length(emblem)-.43);
        ink=1.-smoothstep(.03,.03+aa,ring);
        ink=max(ink,(1.-smoothstep(.045,.045+aa,abs(emblem.y)))*(1.-step(.64,abs(emblem.x))));
    }
    float bars=(1.-smoothstep(.018,.018+aa,abs(p.y-.64)))*(1.-step(.65,abs(p.x)));
    return color*(border*.65+ink*2.+bars)+vec3(.002,.004,.008);
}
