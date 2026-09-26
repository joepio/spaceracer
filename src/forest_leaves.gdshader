shader_type spatial;
render_mode cull_disabled;
uniform float race_time=0.;
uniform sampler2D leaf_color : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D leaf_mask : filter_linear_mipmap, repeat_disable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap, repeat_disable;
varying vec3 tint;
varying flat float shell;
void vertex(){
    vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    float weight=smoothstep(.35,1.,VERTEX.y);
    VERTEX.x+=sin(race_time*.85+world.x*.014+world.z*.018)*.0016*weight;
    VERTEX.z+=cos(race_time*.7+world.y*.025)*.0011*weight;
    tint=COLOR.rgb;
    shell=COLOR.a;
}
void fragment(){
    ALPHA=1.;
    ALPHA_SCISSOR_THRESHOLD=.48;
    ALBEDO=vec3(.055,.12,.026)*tint;
    NORMAL_MAP=vec3(.5,.5,1.);
    if(shell>.5){
        ALPHA=texture(leaf_mask,UV).r;
        vec3 leaf=texture(leaf_color,UV).rgb;
        ALBEDO=leaf*vec3(.36,.48,.38)*tint;
        NORMAL_MAP=texture(leaf_normal,UV).rgb;
        BACKLIGHT=leaf*tint*.025;
    }
    NORMAL_MAP_DEPTH=.25;
    ROUGHNESS=.72;
    SPECULAR=.25;
}
