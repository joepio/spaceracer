shader_type spatial;
#include "res://src/neon_sign.gdshaderinc"
uniform float race_time=0.;
varying float style;
void vertex(){style=INSTANCE_CUSTOM.r;}
void fragment(){
    ALBEDO=vec3(.012,.018,.026);
    ROUGHNESS=.38;
    EMISSION=city_poster_art(UV,style,race_time)*1.8;
}
