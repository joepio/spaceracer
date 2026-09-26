shader_type spatial;
render_mode cull_disabled;
uniform float race_time=0.;
varying vec3 tint;
void vertex(){
    vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    VERTEX.x+=sin(race_time*1.1+world.x*.014+world.z*.018)*.0012;
    VERTEX.z+=cos(race_time*.8+world.y*.025)*.0008;
    tint=COLOR.rgb;
}
void fragment(){
    ALBEDO=tint*vec3(.12,.28,.14);
    ROUGHNESS=.78;
    BACKLIGHT=tint*vec3(.06,.12,.025);
}
