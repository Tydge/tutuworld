shader_type spatial;
render_mode diffuse_burley;
uniform vec4 dye: source_color=vec4(1.);
uniform sampler2D grain: source_color,repeat_enable,filter_linear_mipmap;
varying vec3 sculpt;
void vertex(){sculpt=VERTEX;}
void fragment(){
	vec2 uv=vec2(sculpt.x*.65+sculpt.z*.41,sculpt.y*.62+sculpt.z*.35);
	float pores=texture(grain,uv).r;
	float patch=clamp((pores-(OUTPUT_IS_SRGB ? .835 : .65))*5.+.38,0.,1.);
	vec3 tint=OUTPUT_IS_SRGB ? mix(COLOR.rgb*12.92,1.055*pow(COLOR.rgb,vec3(1./2.4))-.055,greaterThan(COLOR.rgb,vec3(.00313))) : COLOR.rgb;
	float edge=pow(1.-abs(dot(normalize(NORMAL),VIEW)),2.);
	ALBEDO=tint*dye.rgb*mix(vec3(1.20,.97,.83),vec3(.86,1.10,1.05),patch)*(.94+.08*edge);
	METALLIC=mix(.62,.31,patch);
	ROUGHNESS=mix(.33,.62,patch);
}
