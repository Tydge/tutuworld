shader_type spatial;
render_mode unshaded,cull_disabled;
#include "res://assets/shaders/jade_mountain_air.gdshaderinc"
uniform sampler2D hillside : source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D forest : source_color,repeat_disable,filter_linear_mipmap;
uniform vec3 sun_direction = vec3(.46,.65,.60);
varying float relief;
varying vec3 air_tint;
varying float air_amount;

void vertex() {
	mountain_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	vec3 normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	if(normal.y<0.) normal=-normal;
	relief=clamp(dot(normal,sun_direction),-.5,1.);
	vec3 ray=mountain_position-CAMERA_POSITION_WORLD;
	air_tint=skyline_air(ray);
	air_amount=.065+.09*smoothstep(150.,690.,length(ray.xz));
}
void fragment() {
	vec2 slope_uv=mountain_position.xz+mountain_position.y*vec2(.35,.69);
	float stone=dot(texture(hillside,slope_uv*.036).rgb,vec3(.24,.64,.12));
	// A small, fully opaque patch of painted woodland gives the 3D ridges
	// the same scale of foliage as the far mountains. Map it across the
	// slope in metres so the texture follows the ground as the camera moves.
	vec2 land=mat2(vec2(.87,.50),vec2(-.50,.87))*mountain_position.xz;
	vec2 tile=land*vec2(.047,.038)-vec2(0.,mountain_position.y*.09);
	vec2 mirrored=1.-abs(mod(tile,2.)-1.);
	vec3 trees=texture(forest,vec2(.395,.80)+mirrored*vec2(.075,.116)).rgb;
	vec3 ground=mix(COLOR.rgb,trees,.48)*(.89+.67*stone);
	ground*=mix(vec3(.25,.255,.28),vec3(.84,.88,.80),mountain_day)*(.78+.33*relief);
	ALBEDO=mix(ground,air_tint,air_amount);
}
