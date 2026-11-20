shader_type spatial;
render_mode diffuse_burley;

uniform float warmth = 0.0;
uniform vec4 lamp_color : source_color = vec4(1.0,0.78,0.43,1.0);

void fragment() {
	float pane = COLOR.a;
	vec3 base = OUTPUT_IS_SRGB ? mix(12.92*COLOR.rgb,1.055*pow(COLOR.rgb,vec3(1.0/2.4))-0.055,greaterThan(COLOR.rgb,vec3(0.00313))) : COLOR.rgb;
	ALBEDO = mix(base,mix(base,lamp_color.rgb,warmth),pane);
	ROUGHNESS = mix(0.67,0.31,pane);
	METALLIC = (1.0-pane)*0.34;
	EMISSION = lamp_color.rgb * pane * (0.015 + warmth*1.24);
}
