shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never,skip_vertex_transform;
uniform vec3 points[48];
uniform int point_count=0;
uniform float race_time=0.;
uniform float opacity=1.;
uniform bool daylight=false;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
varying float age;
varying float end_fade;
varying vec3 trail_center;
varying vec3 trail_tangent;
void vertex(){
    int index=min(int(round(UV.y*47.)),max(0,point_count-1));
    vec3 center=points[index];
    vec3 tangent=points[max(0,index-1)]-points[min(max(0,point_count-1),index+1)];
    if(length(tangent)<.001) tangent=vec3(0.,0.,1.);
    trail_tangent=normalize(tangent);
    vec3 across=cross(trail_tangent,CAMERA_POSITION_WORLD-center);
    if(length(across)<.001) across=INV_VIEW_MATRIX[0].xyz;
    age=float(index)/47.;
    end_fade=smoothstep(0.,8.,float(point_count-1-index));
    float width=1.1+pow(age,.65)*5.;
    // Broad, slow drift breaks the ruler-straight ribbon without separate puffs.
    center+=vec3(sin(age*8.+race_time*.6),age*1.8,cos(age*7.+race_time*.5))*age*.6;
    trail_center=center;
    center+=normalize(across)*(UV.x*2.-1.)*width;
    VERTEX=(VIEW_MATRIX*vec4(center,1.)).xyz;
}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);
}
void fragment(){
    vec2 q=vec2(UV.x*2.4,age*13.-race_time*.3);
    float cloud=noise(q)*.65+noise(q*2.3+race_time*.09)*.25+noise(q*4.8)*.10;
    float across=abs(UV.x*2.-1.+(cloud-.5)*.18);
    float feather=exp(-across*across*5.)*(1.-smoothstep(.6,1.,across));
    // Soft intersections with craft/road, instead of a sheet cutting through them.
    float scene_depth=texture(depth_texture,SCREEN_UV).r;
    vec3 ndc=vec3(SCREEN_UV*2.-1.,scene_depth);
    #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    ndc.z=scene_depth*2.-1.;
    #endif
    vec4 scene=INV_PROJECTION_MATRIX*vec4(ndc,1.);
    float gap=-scene.z/max(.00001,scene.w)+VERTEX.z;
    float soft=smoothstep(0.,4.,gap);
    // Fade the local ribbon as a camera enters it; never fill a viewport with
    // opaque intersecting triangles or flip a hard plane through the lens.
    vec3 to_camera=CAMERA_POSITION_WORLD-trail_center;
    float near_fade=smoothstep(5.,20.,length(to_camera));
    float axial=abs(dot(normalize(to_camera),normalize(trail_tangent)));
    float grazing=1.-smoothstep(.91,.995,axial)*.65;
    ALBEDO=mix(vec3(.22,.26,.29),vec3(.48,.51,.54),cloud);
    if(daylight) ALBEDO=mix(ALBEDO,vec3(.65,.67,.68),.4);
    EMISSION=vec3(.5,.20,.06)*exp(-age*60.)*feather*.18;
    ALPHA=feather*(.14+cloud*.22)*opacity*end_fade*(1.-smoothstep(.55,1.,age))*soft*near_fade*grazing;
}
