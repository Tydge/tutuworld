shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D skyline : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
#include "res://assets/shaders/jade_mountain_air.gdshaderinc"

void vertex() {
	mountain_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
}
void fragment() {
	vec4 pigment=texture(skyline,UV,.85);
	if(pigment.a<.025) discard;
	vec3 ray=mountain_position-CAMERA_POSITION_WORLD;
	vec3 air=skyline_air(ray);
	float value=dot(pigment.rgb,vec3(.24,.64,.12));
	vec3 rock=mix(vec3(value),pigment.rgb,.72);
	rock*=mix(vec3(.14,.155,.19),vec3(.75,.79,.77),mountain_day);
	float depth=smoothstep(330.,850.,length(ray.xz));
	float haze=.13+.09*depth+.065*smoothstep(.06,.35,value);
	ALBEDO=mix(air,mix(rock,air,haze),smoothstep(.035,.88,pigment.a));
}
