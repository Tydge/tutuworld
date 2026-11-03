shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_prepass_alpha;
uniform vec4 area;
uniform vec4 tint : source_color = vec4(0.95, 0.18, 0.10, 0.4);
varying vec3 world_point;
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	if (world_point.x < area.x - 0.002 || world_point.z < area.y - 0.002 || world_point.x > area.x + area.z + 0.002 || world_point.z > area.y + area.w + 0.002) discard;
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
}
