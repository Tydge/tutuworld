shader_type spatial;
uniform vec4 dye:source_color=vec4(1.);
uniform float warmth=.0;
#include "res://assets/shaders/jade_paper_light.gdshaderinc"
varying vec2 street;
void vertex(){street=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment(){
	vec2 phase=UV*vec2(313.,390.);
	vec2 coverage=1.-smoothstep(vec2(1.),vec2(3.14),fwidth(phase));
	float fibres=.96+.04*coverage.x*coverage.y*sin(phase.y)*sin(phase.x);
	ALBEDO=dye.rgb*mix(vec3(.55,.405,.236),vec3(.77,.43,.14),warmth)*fibres;
	EMISSION=jade_paper_light(UV,street,warmth);
	ROUGHNESS=.95;
}
