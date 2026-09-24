shader_type canvas_item;
render_mode unshaded;
uniform float amount=0.;
void fragment(){
    vec4 original=texture(TEXTURE,UV);
    if(amount>.0001){
        vec2 ray=UV-vec2(.5,.43);
        // Protect the player's ship, road apex and all UI (drawn after this pass).
        float peripheral=smoothstep(.16,.62,length(ray*vec2(1.,.8)));
        float ship_mask=smoothstep(.15,.3,length((UV-vec2(.5,.72))*vec2(1.,.75)));
        vec2 offset=ray*amount*peripheral*ship_mask;
        vec3 sum=original.rgb*.4;
        sum+=texture(TEXTURE,clamp(UV-offset*.25,vec2(.001),vec2(.999))).rgb*.24;
        sum+=texture(TEXTURE,clamp(UV-offset*.5,vec2(.001),vec2(.999))).rgb*.17;
        sum+=texture(TEXTURE,clamp(UV-offset*.75,vec2(.001),vec2(.999))).rgb*.12;
        sum+=texture(TEXTURE,clamp(UV-offset,vec2(.001),vec2(.999))).rgb*.07;
        COLOR=vec4(sum,original.a);
    }else{COLOR=original;}
}
