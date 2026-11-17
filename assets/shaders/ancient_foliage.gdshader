shader_type spatial;
render_mode cull_disabled,diffuse_burley,specular_disabled;
uniform sampler2D foliage_atlas:source_color,filter_linear_mipmap_anisotropic,repeat_disable;
#include "res://assets/shaders/forest_camera_cut.gdshaderinc"
varying vec4 leaf_tint;
vec3 linear_color(vec3 c){return mix(pow((c+vec3(.055))/1.055,vec3(2.4)),c/12.92,lessThan(c,vec3(.04045)));}
void vertex(){
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;forest_vertex=p;forest_camera_pass=(PROJECTION_MATRIX[3][3]<.5 && distance(INV_VIEW_MATRIX[3].xyz,forest_view)<.12)?1.:0.;leaf_tint=COLOR;
 forest_detail=forest_detail_weight(MODEL_MATRIX[3].xyz,MAIN_CAM_INV_VIEW_MATRIX[3].xyz);
 float gust=sin(p.x*.075+p.z*.11+TIME*.65)+.3*sin(p.z*.25-TIME*1.1);
 VERTEX.x+=gust*.06*smoothstep(6.,26.,VERTEX.y);VERTEX.z+=gust*.03*smoothstep(6.,26.,VERTEX.y);
 NORMAL=normalize(vec3(NORMAL.x*.38,abs(NORMAL.y)*.45+.72,NORMAL.z*.38));
}
void fragment(){
 if(forest_lod_discard(FRAGCOORD.xy) || forest_obscures())discard;
 vec4 leaf=texture(foliage_atlas,UV);
 ALPHA=leaf.a;ALPHA_SCISSOR_THRESHOLD=.48;
 vec3 tint=OUTPUT_IS_SRGB?leaf_tint.rgb:linear_color(leaf_tint.rgb);
 ALBEDO=leaf.rgb*tint;ROUGHNESS=.94;BACKLIGHT=ALBEDO*.16;
}
