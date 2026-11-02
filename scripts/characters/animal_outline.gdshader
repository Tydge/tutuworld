shader_type spatial;
render_mode unshaded,cull_front;
uniform float outline_width=.035;
uniform float overlap_bias=.045;
void vertex(){
 mat3 inverse_modelview=inverse(mat3(MODELVIEW_MATRIX));
 vec3 normal_view=normalize(transpose(inverse_modelview)*NORMAL);
 VERTEX+=inverse_modelview*(normal_view*outline_width+vec3(0.0,0.0,overlap_bias));
}
void fragment(){ALBEDO=vec3(.004,.003,.006);}
