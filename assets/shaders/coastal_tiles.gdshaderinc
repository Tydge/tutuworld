uniform bool coastal_tiles = false;
uniform sampler2D barrel_tiles : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

vec3 clay_tiles(vec3 base, vec2 roof) {
	// The tile channels follow the fall of both roof slopes, including rotated player modules.
	vec2 uv = vec2(roof.y * 0.27, abs(roof.x) * 0.32);
	float relief = dot(texture(barrel_tiles,uv).rgb,vec3(.24,.58,.18));
	return base * clamp(relief/(OUTPUT_IS_SRGB ? .60 : .32),0.47,1.60);
}
