shader_type spatial;
render_mode diffuse_burley,specular_disabled;
uniform vec4 bark_color:source_color=vec4(.53,.40,.27,1.);
uniform sampler2D bark_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
#include "res://assets/shaders/forest_camera_cut.gdshaderinc"
uniform bool use_instance_slope=true;
varying float trunk_height;
void vertex(){if(use_instance_slope)VERTEX.y+=dot(VERTEX.xz,INSTANCE_CUSTOM.rg*2.-1.)*(1.-smoothstep(0.,2.2,VERTEX.y));forest_vertex=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;forest_camera_pass=(PROJECTION_MATRIX[3][3]<.5 && distance(INV_VIEW_MATRIX[3].xyz,canopy_observer())<.12)?1.:0.;trunk_height=VERTEX.y;forest_detail=forest_detail_weight(MODEL_MATRIX[3].xyz,MAIN_CAM_INV_VIEW_MATRIX[3].xyz);}
void fragment(){
 if(forest_lod_discard(FRAGCOORD.xy) || forest_obscures())discard;
 vec3 grain=texture(bark_texture,vec2(UV.x,UV.y*1.4)).rgb;
 float value=clamp(dot(grain,vec3(.3,.6,.1))/.19,.57,1.55);
 vec3 bark=bark_color.rgb*mix(.88,value,.72);
 float moss=(1.-smoothstep(.25,2.,trunk_height))*(.65+.35*sin(UV.x*16.));
 ALBEDO=mix(bark,bark*vec3(.76,1.02,.56),moss*.42);ROUGHNESS=.98;
}
