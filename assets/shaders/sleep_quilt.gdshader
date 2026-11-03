shader_type spatial;
render_mode cull_disabled;
uniform bool patterned=true;
uniform float pattern_strength=.78;
uniform float pattern_scale=3.5;
uniform float occupancy=0.0;
uniform float cover_height=.65;
uniform float cover_width=.75;
uniform sampler2D fabric_mask: filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 dye:source_color=vec4(.4,.63,.61,1);
uniform vec4 accent:source_color=vec4(.92,.87,.73,1);
varying vec2 p;
#include "res://assets/shaders/fabric_color.gdshaderinc"
float drape(vec2 q){q.y-=.30;float body=exp(-pow(abs(q.x)/cover_width,4.0))*smoothstep(-.90,-.58,q.y)*(1.0-smoothstep(1.18,1.82,q.y));return occupancy*body*(cover_height+sin(TIME*1.7)*.005)-.11*pow(abs(q.x)/1.24,8.0)+sin(q.x*17.0+q.y*4.0)*.012;}
void vertex(){p=VERTEX.xz+vec2(0,.78);float h=drape(p);VERTEX.y+=h;NORMAL=normalize(vec3((h-drape(p+vec2(.01,0)))/.01,1.0,(h-drape(p+vec2(0,.01)))/.01));}
void fragment(){ALBEDO=fabric_color(p*pattern_scale);ROUGHNESS=.96;SPECULAR=.2;}
