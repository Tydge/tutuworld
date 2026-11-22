shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D skyline : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform vec4 daylight_tint : source_color=vec4(.89,.94,.93,1.);
uniform float night_air=0.;
void fragment(){
	vec4 pigment=texture(skyline,UV);
	if(pigment.a<.47)discard;
	vec3 painted=pigment.rgb*daylight_tint.rgb;
	float ridge=dot(pigment.rgb,vec3(.24,.64,.12));
	// Pale distant peaks catch more moonlit air than the dark ridges in front.
	ALBEDO=painted+night_air*vec3(.025,.053,.102)*smoothstep(.035,.56,ridge);
}
