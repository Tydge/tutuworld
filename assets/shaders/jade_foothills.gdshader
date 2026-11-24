shader_type spatial;
render_mode unshaded,cull_disabled;
#include "res://assets/shaders/jade_mountain_air.gdshaderinc"
uniform sampler2D hillside : source_color,repeat_enable,filter_linear_mipmap_anisotropic;
uniform sampler2D forest : source_color,repeat_enable,filter_linear_mipmap_anisotropic;
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
	vec3 moss=texture(hillside,slope_uv*.036).rgb;
	vec3 weights=abs(normalize(cross(dFdx(mountain_position),dFdy(mountain_position))));
	weights/=max(dot(weights,vec3(1.)),.001);
	vec3 turf=texture(forest,mountain_position.yz*.12).rgb*weights.x
		+texture(forest,mountain_position.xz*.12).rgb*weights.y
		+texture(forest,mountain_position.xy*.12).rgb*weights.z;
	float clearings=smoothstep(.12,.47,dot(texture(forest,mountain_position.xz*.019).rgb,vec3(.27,.62,.11)));
	float spur=sin(mountain_position.x*.065+mountain_position.z*.044+2.6*sin(mountain_position.z*.023));
	float exposed=smoothstep(.03,.24,1.-weights.y)*smoothstep(-.45,.55,spur+.65*clearings);
	vec3 ground=COLOR.rgb*.56+mix(turf*vec3(.43,.54,.48),moss*vec3(.41,.43,.36),.37);
	ground=mix(ground,moss*vec3(.74,.76,.71),exposed*.7);
	ground*=.78+.40*clearings+.12*spur;
	ground*=mix(vec3(.25,.255,.28),vec3(.84,.88,.80),mountain_day)*(.78+.33*relief);
	ALBEDO=mix(ground,air_tint,air_amount);
}
