shader_type spatial;
uniform vec4 dye : source_color;
uniform vec4 accent : source_color;
uniform sampler2D fabric_mask : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool patterned=false;
uniform float pattern_strength=.78;
uniform float pattern_scale=3.0;
#include "res://assets/shaders/fabric_color.gdshaderinc"
void fragment() {
	vec3 base = fabric_color(UV * pattern_scale);
	// Filter the fine warp out when a ribbon occupies only a few screen pixels.
	float warp = UV.y * 212.0;
	float resolved = 1.0-smoothstep(.10,.52,fwidth(warp));
	float threads = cos(TAU*warp) * resolved;
	float grazing = pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.6);
	ALBEDO = base * (.96+.025*threads) + vec3(.115,.045,.035)*grazing;
	ROUGHNESS = .36+.025*threads;
	SPECULAR = .52;
	RIM = .18;
	RIM_TINT = .70;
}
