shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float progress=0.;
uniform mat4 hull_inverse;
varying vec3 hull_position;
void vertex(){
    hull_position=(hull_inverse*MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    VERTEX+=NORMAL*.009;
}
void fragment(){
    float front=mix(-1.,2.6,min(1.,progress*1.4));
    float band=1.-smoothstep(.035,.23,abs(hull_position.y-front));
    vec3 grid=abs(fract(hull_position*vec3(3.,9.,3.))-.5);
    vec3 aa=max(fwidth(hull_position)*vec3(3.,9.,3.),vec3(.012));
    vec3 line=1.-smoothstep(vec3(.015),vec3(.015)+aa,grid);
    float lattice=max(line.y,max(line.x,line.z)*.55);
    float above=smoothstep(front-.05,front+.1,hull_position.y);
    float fade=1.-smoothstep(.60,1.,progress);
    ALBEDO=mix(vec3(.12,.65,1.),vec3(.8,1.,1.),band);
    ALPHA=(band*2.6+lattice*above*.65+(.08+.18*lattice)*(1.-above))*fade;
}
