shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float race_time=0.;
uniform float strike_frame=0.;
uniform float power=0.;
uniform float surge=0.;
uniform vec3 jet_tint : source_color=vec3(.1,.6,1.);
varying float intensity;
float hash(float p){return fract(sin(p*127.1+311.7)*43758.5453);}
vec3 path(float t,float seed,float angle,float reach,float spread){
    vec2 radial=vec2(cos(angle),sin(angle));
    float knot=floor(t*8.+.01);
    vec2 kink=vec2(hash(seed+knot*7.),hash(seed+knot*13.+53.))-.5;
    vec2 offset=radial*spread*pow(t,.72)+kink*sin(t*3.14159)*1.1;
    return vec3(offset,-t*reach);
}
void vertex(){
    float id=floor(COLOR.r*12.+.5);
    float branch=mod(id,6.);
    float fork=step(5.5,id);
    // A fresh strike every render frame; no multi-frame hold or fading tail.
    float seed=branch*83.+strike_frame*17.+floor(race_time*19.)*3.;
    float angle=branch*1.0472+(hash(seed)-.5)*1.5;
    float reach=4.+hash(seed+1.)*7.;
    float spread=.8+hash(seed+2.)*1.8;
    float t=UV.y;
    vec3 point=path(t,seed,angle,reach,spread);
    if(fork>.5){
        point=path(.5,seed,angle,reach,spread)+path(t,seed+71.,angle+1.1,reach*.38,spread*.6);
    }
    vec3 tangent=(MODELVIEW_MATRIX*vec4(cos(angle)*spread,sin(angle)*spread,-reach,0.)).xyz;
    vec2 across=normalize(vec2(-tangent.y,tangent.x)+vec2(.00001,0.));
    vec3 center=(MODELVIEW_MATRIX*vec4(point,1.)).xyz;
    float width=mix(.13,.075,fork)*(1.-t*.8)*(1.+surge*.35);
    VERTEX=center+vec3(across*(UV.x*2.-1.)*width,0.);
    MODELVIEW_MATRIX=mat4(1.);
    // Sparse flashes leave gaps instead of forming a continuous electrical cage.
    intensity=step(.68,hash(seed+6.))*(1.-smoothstep(.65,1.,t))*mix(1.,.7,fork);
}
void fragment(){
    float across=abs(UV.x*2.-1.);
    float core=exp(-across*across*32.);
    ALBEDO=mix(jet_tint*1.8,vec3(.8,.94,1.)*3.5,core);
    ALPHA=(1.-smoothstep(.25,1.,across))*intensity*power*(.55+surge*.45);
}
