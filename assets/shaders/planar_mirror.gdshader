shader_type spatial;
render_mode cull_back;
uniform sampler2D reflection_texture : source_color, filter_linear, repeat_disable;
uniform bool reflection_ready = false;
void fragment() {
	if (length((UV - vec2(0.5)) * 2.0) > 1.0) discard;
	ALBEDO = vec3(0.72, 0.77, 0.75);
	METALLIC = 0.65;
	ROUGHNESS = 0.055;
	if (reflection_ready) {
		ALBEDO = vec3(0.0);
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
		EMISSION = texture(reflection_texture, vec2(1.0 - UV.x, UV.y)).rgb;
	}
}
