shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled,shadows_disabled;
// Camera-facing water effects. kind: 0 marine snow wrapped around the camera,
// 1 rising bubble columns, 2 soft shafts of light from the surface,
// 3 glow halos around bioluminescent bulbs.
uniform int kind=0;
uniform float race_time=0.;
varying float fade;
varying float variant;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
    vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex(){
    vec3 cam=INV_VIEW_MATRIX[3].xyz;
    vec3 center=MODEL_MATRIX[3].xyz;
    vec3 scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
    variant=hash(vec2(float(INSTANCE_ID),3.1));
    fade=1.;
    if(kind==2){
        // Shafts lean with the sunlight and turn only around their own axis.
        vec3 axis=normalize(vec3(.22,1.,.12));
        vec3 to_camera=cam-center;to_camera-=axis*dot(to_camera,axis);
        vec3 z=normalize(to_camera+vec3(1e-4));
        vec3 x=normalize(cross(axis,z));
        MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(x*scale.x,0.),vec4(axis*scale.y,0.),vec4(z,0.),vec4(center+axis*scale.y*.5,1.));
        fade=smoothstep(25.,90.,length(cam-center-axis*dot(cam-center,axis)))*(.6+.4*sin(race_time*.4+variant*20.));
    }else{
        if(kind==0){
            center.y-=race_time*.5;
            center.xz+=vec2(sin(race_time*.2+variant*6.),cos(race_time*.17+variant*5.))*2.;
            center=cam+mod(center-cam+80.,160.)-80.;
            float d=length(center-cam);
            fade=smoothstep(2.,8.,d)*(1.-smoothstep(45.,80.,d));
        }else if(kind==1){
            float height=COLOR.r*200.;
            float speed=COLOR.g*10.;
            float rise=mod(race_time*speed+variant*height*3.7,height);
            center.y+=rise;
            center.x+=sin(rise*.25+variant*9.)*1.6;
            center.z+=cos(rise*.21+variant*7.)*1.6;
            scale*=.6+.8*rise/height;
            fade=smoothstep(0.,4.,rise)*(1.-smoothstep(height*.8,height,rise));
        }
        MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*scale.x,INV_VIEW_MATRIX[1]*scale.y,INV_VIEW_MATRIX[2]*scale.z,vec4(center,1.));
    }
    MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
}
void fragment(){
    vec2 p=UV-.5;
    float d=length(p)*2.;
    vec3 color;
    float alpha;
    if(kind==0){
        float glowing=step(.94,variant);
        color=mix(vec3(.75,.9,.95),vec3(.3,1.,.85),glowing);
        alpha=(1.-smoothstep(.2,1.,d))*fade*mix(.35,.9,glowing);
    }else if(kind==1){
        // A thin bright rim with a highlight: an air bubble seen in water.
        float rim=smoothstep(.65,.85,d)*(1.-smoothstep(.88,1.,d));
        float highlight=1.-smoothstep(.0,.25,length(p-vec2(-.15,-.18)));
        color=vec3(.8,.95,1.);
        alpha=(rim*.7+highlight*.8)*fade;
    }else if(kind==3){
        float pulse=.7+.3*sin(race_time*1.4+variant*40.);
        color=COLOR.rgb;
        alpha=pow(max(1.-d,0.),1.8)*.85*pulse;
    }else{
        float across=1.-abs(UV.x*2.-1.);
        float streaks=noise(vec2(UV.x*7.+variant*13.,UV.y*.6+race_time*.03))*.6+.4;
        float vertical=smoothstep(1.,.55,UV.y)*smoothstep(0.,.35,UV.y);
        color=vec3(.4,.8,.85);
        alpha=pow(across,2.2)*streaks*vertical*fade*.08;
    }
    ALBEDO=color;
    ALPHA=clamp(alpha,0.,1.);
}
