shader_type spatial;
render_mode specular_disabled;
uniform vec4 soil_color : source_color=vec4(.58,.36,.19,1);
uniform sampler2D soil_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec3 texture_mean=vec3(.644,.309,.086);
uniform float texture_scale=.48;
uniform float detail_strength=.62;
uniform bool vertex_tint=false;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 sample_color=texture(soil_texture,world_pos.xz*texture_scale).rgb;
 vec3 variation=clamp(sample_color/texture_mean,vec3(.55),vec3(1.50));
 float mound_shade=vertex_tint?dot(COLOR.rgb,vec3(.333333)):1.0;
 ALBEDO=soil_color.rgb*mix(vec3(1.0),variation,detail_strength)*mound_shade;
 ROUGHNESS=1.0;
}
