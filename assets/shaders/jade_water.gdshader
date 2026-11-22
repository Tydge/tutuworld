shader_type spatial;
render_mode diffuse_burley,cull_back,depth_draw_never;
#include "res://assets/shaders/painted_water.gdshaderinc"
uniform sampler2D river_banks:source_color,repeat_disable,filter_linear_mipmap;

float river_z(float x){return 9.*sin(x*.015);}

void vertex(){
	water_world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	water_base_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment(){
	vec2 p=water_world.xz;
	vec3 n=ripple_flow(p,flow);
	vec3 eye=normalize(CAMERA_POSITION_WORLD-water_world);
	float depth=water_thickness(SCREEN_UV,INV_PROJECTION_MATRIX,VERTEX.z);
	float fresnel=pow(1.-clamp(dot(n,eye),0.,1.),3.);
	float foam=(1.-smoothstep(.08,.55,depth))*smoothstep(.52,.79,.65+(n.x+n.z)*1.5);
	vec3 water=water_tint(depth,fresnel)+vec3(.42,.52,.48)*foam*.35;
	float canal=(1.-smoothstep(11.,19.,abs(p.y-river_z(p.x))))*(1.-smoothstep(157.,191.,abs(p.x)));
	vec3 reflection=reflect(-eye,normalize(vec3(n.x*.46,1.,n.z*.46)));
	float side=reflection.z<0.?-1.:1.;
	float dz=max(abs(reflection.z),.075)*side;
	float travel=(river_z(p.x)+side*19.-p.y)/dz;
	travel=(river_z(p.x+reflection.x*clamp(travel,0.,100.))+side*19.-p.y)/dz;
	vec3 at=water_world+reflection*travel;
	float h=(34.-at.y)/36.;
	vec2 uv=vec2((at.x+216.)/432.,(clamp(h,.008,.992)+step(0.,side))*.5);
	vec4 bank=texture(river_banks,uv);
	float valid=smoothstep(.01,.14,abs(reflection.z))*smoothstep(0.,2.,travel)*(1.-smoothstep(70.,120.,travel))*smoothstep(-.10,.03,h);
	float light=clamp(daylight,0.,1.);
	vec3 skyline=mix(horizon_color.rgb*.58,bank.rgb*mix(vec3(.24,.30,.39),vec3(.78,.88,.85),light),bank.a*valid);
	vec3 body=mix(water*.67,vec3(.027,.100,.092),.47);
	water=mix(water,mix(body,skyline,(.25+.56*fresnel)*(.74+.26*light)),canal);
	NORMAL=normalize((VIEW_MATRIX*vec4(n,0.)).xyz);
	ALBEDO=water;
	ROUGHNESS=mix(.23,.37,smoothstep(28.,140.,length(VERTEX)));
	SPECULAR=mix(.64,.33,canal);
	ALPHA=clamp(mix(.36,.96,1.-exp(-depth*.29))+fresnel*.32+foam*.25+canal*.22,.25,.995);
}
