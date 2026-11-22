shader_type spatial;
render_mode cull_disabled,specular_disabled;
uniform sampler2D foliage:source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform bool bough=false;
uniform vec4 dye:source_color=vec4(1.);
#include "res://assets/shaders/forest_camera_cut.gdshaderinc"
void vertex(){
	vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	forest_vertex=p;
	forest_camera_pass=(PROJECTION_MATRIX[3][3]<.5 && distance(INV_VIEW_MATRIX[3].xyz,canopy_eye)<.12)?1.:0.;
	float gust=sin(TIME*1.27+p.x*.17+p.z*.13)+.35*sin(TIME*2.1+p.y*.96);
	float stem=smoothstep(2.55,6.7,VERTEX.y);
	VERTEX.xz+=vec2(.047,.024)*gust*stem;
}
void fragment(){
	if(forest_obscures())discard;
	vec4 col=bough?texture(foliage,UV):COLOR;
	if(bough && col.a<.42)discard;
	ALBEDO=col.rgb*dye.rgb;ROUGHNESS=.90;BACKLIGHT=col.rgb*.27;
}
