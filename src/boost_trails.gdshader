shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never,skip_vertex_transform,fog_disabled;
uniform vec3 points[32];
uniform float ages[32];
uniform int point_count=0;
uniform vec3 tint=vec3(.2,.8,1.);
varying float age;
varying float end_fade;
varying float camera_fade;
void vertex(){
    int index=min(int(round(UV.y*31.)),max(0,point_count-1));
    vec3 center=points[index];
    vec3 tangent=points[max(0,index-1)]-points[min(max(0,point_count-1),index+1)];
    if(length(tangent)<.001) tangent=vec3(0.,0.,1.);
    vec3 across=cross(normalize(tangent),CAMERA_POSITION_WORLD-center);
    if(length(across)<.001) across=INV_VIEW_MATRIX[0].xyz;
    age=ages[index];
    end_fade=smoothstep(0.,2.,float(point_count-1-index));
    camera_fade=smoothstep(1.,5.,distance(CAMERA_POSITION_WORLD,center));
    center+=normalize(across)*(UV.x*2.-1.)*(.30+age*.28);
    VERTEX=(VIEW_MATRIX*vec4(center,1.)).xyz;
}
void fragment(){
    float x=UV.x*2.-1.;
    float core=exp(-x*x*130.);
    float glow=exp(-x*x*12.);
    // Offset color shoulders recall analog phosphor bleed without smearing HUD.
    vec3 bleed=vec3(1.,.08,.16)*exp(-pow(x-.26,2.)*50.)
              +vec3(.03,.65,1.)*exp(-pow(x+.26,2.)*50.);
    vec3 ink=tint*glow*.85+mix(tint,vec3(1.),.35)*core*4.+bleed*.32;
    ALBEDO=ink;
    ALPHA=pow(max(0.,1.-age),2.2)*end_fade*camera_fade*(1.-smoothstep(.7,1.,abs(x)));
}
