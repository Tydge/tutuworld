// Fixed lattice samples keep neighboring cloud cells identical across GPU backends.
global uniform sampler2D sky_lattice : repeat_enable, filter_linear;
global uniform sampler2D sky_stars : repeat_enable, filter_linear_mipmap;
float noise(vec2 p) {
	vec2 f = fract(p);
	vec2 eased = f * f * (3.0 - 2.0 * f);
	return textureLod(sky_lattice, (floor(p) + eased + 0.5) / 128.0, 0.0).r;
}
float starlight(vec2 uv) {
	// Wrap longitude gradients at the meridian before selecting a mip level.
	vec2 dx = dFdx(uv), dy = dFdy(uv);
	dx.x -= round(dx.x);
	dy.x -= round(dy.x);
	return textureGrad(sky_stars, uv, dx, dy).r;
}
