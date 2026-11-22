shader_type spatial;
uniform vec4 dye:source_color=vec4(1.);
uniform float warmth=.0;
void fragment(){
	float fibres=.96+.04*sin(UV.y*390.)*sin(UV.x*313.);
	ALBEDO=dye.rgb*mix(vec3(.55,.405,.236),vec3(.77,.43,.14),warmth)*fibres;
	EMISSION=vec3(.93,.46,.13)*warmth*.68;
	ROUGHNESS=.95;
}
