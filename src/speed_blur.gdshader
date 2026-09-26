shader_type canvas_item;
render_mode unshaded;
uniform float amount=0.;
uniform float warp=0.;
uniform float race_time=0.;
void fragment(){
    vec4 original=texture(TEXTURE,UV);
    if(amount>.0001){
        vec2 ray=UV-vec2(.5,.43);
        // Protect the player's ship, road apex and all UI (drawn after this pass).
        float peripheral=smoothstep(.13,.57,length(ray*vec2(1.,.8)));
        float ship_mask=smoothstep(.15,.3,length((UV-vec2(.5,.72))*vec2(1.,.75)));
        vec2 offset=ray*amount*peripheral*ship_mask;
        vec3 sum=original.rgb*.24;
        sum+=texture(TEXTURE,clamp(UV-offset*.142857,vec2(.001),vec2(.999))).rgb*.18;
        sum+=texture(TEXTURE,clamp(UV-offset*.285714,vec2(.001),vec2(.999))).rgb*.15;
        sum+=texture(TEXTURE,clamp(UV-offset*.428571,vec2(.001),vec2(.999))).rgb*.13;
        sum+=texture(TEXTURE,clamp(UV-offset*.571429,vec2(.001),vec2(.999))).rgb*.11;
        sum+=texture(TEXTURE,clamp(UV-offset*.714286,vec2(.001),vec2(.999))).rgb*.085;
        sum+=texture(TEXTURE,clamp(UV-offset*.857143,vec2(.001),vec2(.999))).rgb*.06;
        sum+=texture(TEXTURE,clamp(UV-offset,vec2(.001),vec2(.999))).rgb*.045;
        COLOR=vec4(sum,original.a);
    }else{COLOR=original;}
    if(warp>.001){
        vec2 ray=UV-vec2(.5,.43);
        float radius=length(ray);
        float peripheral=smoothstep(.07,.65,radius);
        float angle=atan(ray.y,ray.x);
        float ripple=sin(radius*35.-race_time*9.+angle*2.);
        vec2 bend=ray*(ripple*.055+sin(angle*5.+race_time*1.5)*.028)*warp*peripheral;
        vec2 chroma=ray*.024*warp*peripheral;
        vec2 at=clamp(UV+bend,vec2(.003),vec2(.997));
        vec3 refracted=vec3(texture(TEXTURE,clamp(at+chroma,vec2(.003),vec2(.997))).r,texture(TEXTURE,at).g,texture(TEXTURE,clamp(at-chroma,vec2(.003),vec2(.997))).b);
        float rings=pow(max(0.,sin(radius*28.-race_time*7.)),12.)*peripheral;
        vec3 prism=.5+.5*cos(angle+race_time*.7+vec3(0.,2.,4.));
        COLOR.rgb=mix(COLOR.rgb,refracted,warp*.85)+prism*rings*warp*.22;
    }
}
