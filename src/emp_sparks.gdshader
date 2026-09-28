shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float age=0.;
uniform float strength=1.;
uniform float seed=0.;
varying float intensity;
float hash(float value){ return fract(sin(value*127.1+311.7)*43758.5453); }
void vertex(){
    float id=floor(COLOR.r*8.+.5);
    // Independent 25 Hz strikes, with quiet gaps: about two small arcs at once.
    // The shutdown timer freezes with gameplay, including the shape of each bolt.
    float tick=age*25.+id*.37;
    float strike=seed*91.+id*53.+floor(tick)*17.;
    float knot=floor(UV.y*8.+.5);
    float envelope=sin(UV.y*3.141593);
    vec3 kink=vec3(hash(strike+knot*7.),hash(strike+knot*13.+19.),hash(strike+knot*23.+31.))-.5;
    vec3 point=VERTEX-vec3(0.,(UV.x*2.-1.)*.075,0.)+kink*vec3(.20,.32,.20)*envelope;
    vec3 tangent=(MODELVIEW_MATRIX*vec4(TANGENT,0.)).xyz;
    vec2 across=normalize(vec2(-tangent.y,tangent.x)+vec2(.00001,0.));
    vec3 center=(MODELVIEW_MATRIX*vec4(point,1.)).xyz;
    VERTEX=center+vec3(across*(UV.x*2.-1.)*.11,0.);
    MODELVIEW_MATRIX=mat4(1.);
    intensity=step(.70,hash(strike+5.))*(1.-smoothstep(.55,1.,fract(tick)));
}
void fragment(){
    float across=abs(UV.x*2.-1.);
    float core=exp(-across*across*30.);
    float halo=exp(-across*across*7.)*.22;
    float ends=mix(.65,1.,sin(UV.y*3.141593));
    ALBEDO=mix(vec3(.18,.48,1.)*2.,vec3(.85,.96,1.)*6.,core);
    ALPHA=(core+halo)*ends*intensity*strength;
    if(ALPHA<.004){ discard; }
}
