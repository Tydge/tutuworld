varying vec3 p; varying vec3 n; varying vec3 v;
uniform vec4 dye: source_color;
uniform vec4 accent: source_color;
uniform sampler2D fabric_mask: filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool patterned=false;
uniform float pattern_strength=.78;
uniform float pattern_scale=12.0;
uniform int cut=0;
uniform float roughness_value=.96;
uniform float specular_value=.25;
#include "res://assets/shaders/fabric_color.gdshaderinc"
void vertex(){
 v=VERTEX;
 vec3 s=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 p=VERTEX*s;n=normalize(NORMAL/s);
}
void fragment(){
 if(cut==1 && v.z>0.12 && abs(v.x)<0.28)discard;
 if(cut==2 && v.y>0.20)discard;
 vec3 w=pow(abs(normalize(n)),vec3(4));w/=max(w.x+w.y+w.z,.0001);
 ALBEDO=fabric_color(p.zy*pattern_scale)*w.x+fabric_color(p.xz*pattern_scale)*w.y+fabric_color(p.xy*pattern_scale)*w.z;
 ROUGHNESS=roughness_value;SPECULAR=specular_value;
}
