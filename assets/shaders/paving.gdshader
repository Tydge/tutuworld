shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 stone_color : source_color = vec4(0.49,0.56,0.53,1.0);
uniform sampler2D paving_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float texture_scale=.27;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 sample_color=texture(paving_texture,world_pos.xz*texture_scale).rgb;
 vec3 variation=clamp(sample_color/vec3(.2825,.2961,.2988),vec3(.45),vec3(1.50));
 ALBEDO=stone_color.rgb*mix(vec3(1.0),variation,.85);
 ROUGHNESS=.96;
}
