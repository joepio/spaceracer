shader_type spatial;
render_mode diffuse_burley;
varying vec3 local_point;
varying vec4 tint;
void vertex() { local_point=VERTEX; tint=COLOR; }
void fragment() {
    float grain=sin(local_point.x*121.+sin(local_point.z*83.))*sin(local_point.y*97.+local_point.z*31.);
    float folds=sin(local_point.y*42.+sin(local_point.x*18.)*2.+sin(local_point.z*21.));
    float rim=pow(1.-max(dot(normalize(NORMAL),normalize(VIEW)),0.),3.);
    ALBEDO=pow(tint.rgb,vec3(1.45))*(.62+.1*folds+.04*grain);
    ROUGHNESS=.39+.07*grain;
    METALLIC=.06;
    SPECULAR=.65;
    // Thin tissue glows at the rim; shaded interiors keep their depth.
    EMISSION=tint.rgb*(.015+rim*.19);
}
