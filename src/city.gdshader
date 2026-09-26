shader_type spatial;
#include "res://src/city_surface.gdshaderinc"
uniform sampler2D facade : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying highp vec3 world_position;
varying highp vec3 world_normal;
// Instance attributes select discrete facade styles; interpolation roundoff near
// a floor() boundary otherwise alternates styles and UV offsets within a face.
varying flat vec3 tint;
varying flat float facade_weight;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize(transpose(inverse(mat3(MODEL_MATRIX)))*NORMAL);tint=COLOR.rgb;facade_weight=COLOR.a;}
void fragment(){
    city_surface(facade,world_position,world_normal,tint,facade_weight,length(VERTEX),ALBEDO,EMISSION);
    METALLIC=.62;
    ROUGHNESS=.35;
}
