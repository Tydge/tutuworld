shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
varying float life;
void vertex(){float seed=COLOR.r*17.0;life=fract(TIME*(.25+COLOR.r*.08)+COLOR.r);VERTEX.y+=life*.90;VERTEX.x+=sin(seed+life*5.0)*.10*life;}
void fragment(){vec2 q=(UV-.5)*2.0;float dot_=max(0.0,1.0-length(q));ALBEDO=vec3(1.0,.49,.10);EMISSION=ALBEDO*.8;ALPHA=dot_*(1.0-life)*(1.0-life)*smoothstep(.02,.13,life);}
