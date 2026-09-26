shader_type spatial;
render_mode cull_disabled;
uniform float race_time=0.;
uniform sampler2D ripples : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D shore_map : filter_linear_mipmap, repeat_disable;
varying vec3 world;
void vertex(){
    world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    // Long, low swells; high-frequency detail stays in the normal map.
    float wave=sin(dot(world.xz,vec2(.008,.006))+race_time*.48)*.25;
    wave+=sin(dot(world.xz,vec2(-.005,.011))-race_time*.37)*.18;
    VERTEX.y+=wave;
    world.y+=wave;
}
void fragment(){
    vec2 uv=world.xz;
    vec3 a=texture(ripples,uv*.022+vec2(.008,.004)*race_time).rgb*2.-1.;
    vec3 b=texture(ripples,mat2(vec2(.8,.6),vec2(-.6,.8))*uv*.061-vec2(.011,.008)*race_time).rgb*2.-1.;
    float distance_to_eye=length(VERTEX);
    float detail=1.-smoothstep(160.,1200.,distance_to_eye)*.75;
    vec2 slope=(a.xy*.12+b.xy*.055)*detail;
    slope+=cos(dot(uv,vec2(.008,.006))+race_time*.48)*vec2(.002,.0015);
    vec3 n=normalize(vec3(-slope.x,1.,-slope.y));
    NORMAL=normalize(mat3(VIEW_MATRIX)*n);
    float shore=texture(shore_map,uv/7680.+.5).r;
    // Dielectric water: absorption below, sky/probe Fresnel reflections above.
    ALBEDO=mix(vec3(.004,.022,.027),vec3(.025,.095,.068),shore*shore);
    float foam=smoothstep(.88,.99,shore)*(1.-smoothstep(.99,1.,shore));
    foam*=smoothstep(.03,.35,a.x+b.y+sin(race_time*.65+shore*28.)*.4);
    ALBEDO=mix(ALBEDO,vec3(.36,.45,.39),foam*.35);
    ROUGHNESS=mix(.16,.27,smoothstep(300.,1800.,distance_to_eye))+foam*.15;
    METALLIC=0.;
    SPECULAR=.5;
}
