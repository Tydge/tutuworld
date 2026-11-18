shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D bough_atlas : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
void fragment(){
 vec4 leaf=texture(bough_atlas,UV);
 ALBEDO=leaf.rgb*.78;
 ALPHA=leaf.a;ALPHA_SCISSOR_THRESHOLD=.45;
 ROUGHNESS=.91;SPECULAR=.22;
 BACKLIGHT=vec3(.10,.15,.14)*(.2+leaf.g*.25);
}
