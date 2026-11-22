// BoxMesh lays its six panels in a three-by-two atlas. Use the same paper in both house LODs.
vec3 jade_paper_light(vec2 uv, vec2 world_lane, float wick_power) {
	vec2 pane = fract(uv * vec2(3.0, 2.0));
	float room = 0.5 + 0.5 * sin(dot(world_lane, vec2(0.167, 0.139)));
	vec2 hearth = vec2(mix(0.24, 0.72, room), 0.68);
	vec2 offset = (pane - hearth) * vec2(1.1, 1.38);
	float pool = 1.0 / (1.0 + 9.0 * dot(offset, offset));
	return mix(vec3(0.48, 0.19, 0.045), vec3(1.0, 0.60, 0.22), pool)
			* wick_power * mix(0.48, 1.05, room) * (0.28 + 0.89 * pool);
}
