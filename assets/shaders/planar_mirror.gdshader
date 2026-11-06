shader_type spatial;
render_mode cull_back;
uniform sampler2D reflection_texture : source_color, filter_linear, repeat_disable;
uniform bool reflection_ready = false;
uniform float reflection_mix : hint_range(0.0, 1.0) = 0.0;
uniform vec3 reflection_uv_x = vec3(-1.0, 0.0, 1.0);
uniform vec3 reflection_uv_y = vec3(0.0, 1.0, 0.0);
void fragment() {
	if (length((UV - vec2(0.5)) * 2.0) > 1.0) discard;
	ALBEDO = vec3(0.72, 0.77, 0.75);
	METALLIC = 0.65;
	ROUGHNESS = 0.055;
	if (reflection_ready) {
		ALBEDO *= 1.0 - reflection_mix;
		METALLIC *= 1.0 - reflection_mix;
		ROUGHNESS = mix(ROUGHNESS, 1.0, reflection_mix);
		vec3 uv = vec3(UV, 1.0);
		EMISSION = texture(reflection_texture, vec2(dot(reflection_uv_x, uv), dot(reflection_uv_y, uv))).rgb * reflection_mix;
	}
}
