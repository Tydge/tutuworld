uniform sampler2D lawn_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
vec3 lawn_albedo(vec2 position,float patch){
 vec3 leaves=texture(lawn_texture,position*.55).rgb;
 return mix(vec3(.095,.30,.072),leaves,.40)*(.93+patch*.13);
}
