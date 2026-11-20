shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D timber:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 tint:source_color=vec4(.78,.61,.40,1.);
varying vec2 grain;
varying vec2 board;
varying flat vec2 size_;
varying flat float decking;
void vertex(){
 vec3 size=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 vec3 p=VERTEX*size;
 vec3 n=abs(NORMAL);
 vec2 plane=n.y>.65?p.xz:(n.x>n.z?p.zy:p.xy);
 vec2 extent=n.y>.65?size.xz:(n.x>n.z?size.zy:size.xy);
 board=extent.x>extent.y?plane:plane.yx;
 size_=extent.x>extent.y?extent:extent.yx;
 vec3 origin=MODEL_MATRIX[3].xyz;
 float offset=fract(sin(dot(origin.xz,vec2(31.71,19.31)))*13749.41);
 grain=board*vec2(.26,.64)+vec2(offset,offset*.67);
 decking=(n.y>.65 && size.y<.16 && size_.x>2.65 && size_.y>.50 && size_.y<.86)?1.:0.;
}
void fragment(){
 vec3 wood=texture(timber,grain).rgb;
 float value=dot(wood,vec3(.27,.56,.17));
 ALBEDO=tint.rgb*clamp(.66+value*1.65,.66,1.27);
 if(decking>.5){
  vec2 edge=abs(abs(board)-size_*.5+vec2(.13,.12));
  float aa=clamp(fwidth(edge.x)+fwidth(edge.y),.002,.019);
  ALBEDO*=mix(1.,.40,1.-smoothstep(.018-aa,.018+aa,length(edge)));
 }
 ROUGHNESS=.83;
}
