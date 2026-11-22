shader_type spatial;
uniform vec4 dye:source_color=vec4(1.);
uniform float warmth=.0;
#include "res://assets/shaders/jade_paper_light.gdshaderinc"
varying vec2 street;
void vertex(){street=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment(){
	float fibres=.96+.04*sin(UV.y*390.)*sin(UV.x*313.);
	ALBEDO=dye.rgb*mix(vec3(.55,.405,.236),vec3(.77,.43,.14),warmth)*fibres;
	EMISSION=jade_paper_light(UV,street,warmth);
	ROUGHNESS=.95;
}
