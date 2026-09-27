shader_type spatial;
#include "res://src/neon_sign.gdshaderinc"
uniform vec4 neon_color : source_color=vec4(.1,.8,1.,1.);
uniform float style=0.;
void fragment(){
    ALBEDO=vec3(.012,.018,.026);
    ROUGHNESS=.38;
    EMISSION=neon_sign_art(UV,style,neon_color.rgb)*3.;
}
