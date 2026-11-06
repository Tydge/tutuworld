shader_type spatial;
render_mode unshaded,cull_front,depth_draw_never;
uniform vec4 outline_color : source_color = vec4(.36,.86,.66,1.);
uniform float width = 2.;
void vertex(){
 vec4 clip=PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.);
 vec2 direction=(PROJECTION_MATRIX*vec4(MODELVIEW_NORMAL_MATRIX*NORMAL,0.)).xy;
 if(length(direction)>.0001)clip.xy+=normalize(direction)*width*2./VIEWPORT_SIZE*clip.w;
 POSITION=clip;
}
void fragment(){ALBEDO=outline_color.rgb;}
