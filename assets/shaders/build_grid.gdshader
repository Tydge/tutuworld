shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled;
varying vec2 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment(){vec2 edge=abs(fract(p+.5)-.5);vec2 width=fwidth(p)*1.5;float line=1.-min(smoothstep(0.,width.x,edge.x),smoothstep(0.,width.y,edge.y));ALBEDO=vec3(.83,.94,.83);ALPHA=line*.28;}
