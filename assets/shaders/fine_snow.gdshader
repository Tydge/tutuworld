shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
void vertex(){
 vec4 center=MODELVIEW_MATRIX*vec4(0.,0.,0.,1.);
 float near_fade=smoothstep(1.,2.8,length(center.xyz));
 vec4 clip=PROJECTION_MATRIX*center;
 clip.xy+=(UV*2.-1.)*vec2(1.6/VIEWPORT_SIZE.x,1.6/VIEWPORT_SIZE.y)*clip.w*near_fade;
 POSITION=clip;
}
void fragment(){
 float dot_=1.-smoothstep(.40,.9,length(UV*2.-1.));
 ALBEDO=vec3(.94,.97,1.);ALPHA=dot_*.54;
}
