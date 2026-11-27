// Fixed lattice samples keep neighboring cloud cells identical across GPU backends.
global uniform sampler2D sky_lattice : repeat_enable, filter_linear;
float noise(vec2 p) {
	vec2 f = fract(p);
	vec2 eased = f * f * (3.0 - 2.0 * f);
	return textureLod(sky_lattice, (floor(p) + eased + 0.5) / 128.0, 0.0).r;
}
// The upper hemisphere maps continuously to a disk. Each occupied cell holds
// one star fixed in the sky, filtered over the pixels of the active camera.
float starlight(vec3 direction) {
	vec2 grid = 128.0 * direction.xz / (1.0 + abs(direction.y));
	vec2 cell = floor(grid);
	vec2 dx = dFdx(grid), dy = dFdy(grid);
	float light = smoothstep(.955, 1.0, noise(cell));
	if (light == 0.) { return 0.; }
	vec2 center = .25 + .5 * vec2(noise(cell + vec2(37, 19)), noise(cell + vec2(11, 71)));
	vec2 offset = fract(grid) - center;
	float pixel_area = max(abs(dx.x * dy.y - dx.y * dy.x), 1e-10);
	vec2 pixels = vec2(offset.x * dy.y - offset.y * dy.x, dx.x * offset.y - dx.y * offset.x) / pixel_area;
	return .62 * light * exp(-1.65 * dot(pixels, pixels));
}
