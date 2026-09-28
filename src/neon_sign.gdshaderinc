// Full-color corporate posters, shared with the road's bounded reflections.
uniform sampler2D corporate_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
vec3 city_poster_art(vec2 uv, float style, float clock){
    float design=floor(style+.5);
    vec2 tile=vec2(mod(design,3.),floor(design/3.));
    vec3 art=texture(corporate_atlas,(tile+clamp(uv,vec2(.002),vec2(.998)))/vec2(3.,2.)).rgb;
    float refresh=1.-smoothstep(.003,.018,abs(fract(uv.y-clock*.025)-.5));
    return art*(1.-refresh*.02);
}
