shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform float strength=0.0;
uniform vec4 glow_color : source_color=vec4(1.0,.67,.25,1.0);
uniform bool billboard=false;
void vertex(){
 if(billboard){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
}
void fragment(){
 float r=length(UV-.5)*2.0;
 float halo=pow(max(0.0,1.0-r),2.7);
 ALBEDO=glow_color.rgb;
 ALPHA=halo*strength;
}
