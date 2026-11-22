shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D skyline : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform vec4 daylight_tint : source_color=vec4(.89,.94,.93,1.);
void fragment(){
	vec4 pigment=texture(skyline,UV);
	if(pigment.a<.47)discard;
	ALBEDO=pigment.rgb*daylight_tint.rgb;
}
