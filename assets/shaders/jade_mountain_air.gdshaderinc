// Only the two mountain materials use these colours. Match the same angular
// horizon gradient as island_sky, including the dawn and dusk palettes.
uniform vec4 air_horizon : source_color = vec4(.47,.72,.92,1.);
uniform vec4 air_zenith : source_color = vec4(.29,.55,.90,1.);
uniform float mountain_day = 1.;
varying vec3 mountain_position;

vec3 skyline_air(vec3 ray) {
	return mix(air_horizon.rgb,air_zenith.rgb,pow(clamp(normalize(ray).y,0.,1.),.48));
}
