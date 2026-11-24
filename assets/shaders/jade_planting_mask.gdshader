shader_type canvas_item;
render_mode unshaded;
#include "res://assets/shaders/jade_paths.gdshaderinc"

void fragment() {
	vec2 p=UV*512.-256.;
	float lane,palace,avenue,river,fan_width,gate_yard;
	float road=jade_road(p,lane,palace,avenue,river,fan_width,gate_yard);
	// Leave room for the width of the clump and the half-metre mask cells.
	float planted=float(road>1.25 && jade_gravel(p)<.05);
	COLOR=vec4(vec3(planted),1.);
}
