shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform float opacity=1.0;
uniform sampler2D bark_texture:source_color,filter_linear_mipmap,repeat_enable;
varying vec3 local;
varying flat float player_view;
varying vec3 face_normal;
void vertex(){
 local=VERTEX;
 player_view=(PROJECTION_MATRIX[3][3]<.5 && distance(INV_VIEW_MATRIX[3].xyz,MAIN_CAM_INV_VIEW_MATRIX[3].xyz)<.01 && dot(INV_VIEW_MATRIX[2].xyz,MAIN_CAM_INV_VIEW_MATRIX[2].xyz)>.9999)?1.:0.;
 float leaf=smoothstep(.54,.95,COLOR.a);
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 VERTEX.x+=leaf*.021*sin(p.x*1.8+p.z*.94+TIME*1.36);
 face_normal=MODELVIEW_NORMAL_MATRIX*NORMAL;
}
void fragment(){
 if(player_view>.5 && opacity<.999 && opacity<=fract(52.9829189*fract(dot(floor(FRAGCOORD.xy),vec2(.06711056,.00583715)))))discard;
 vec3 tint=OUTPUT_IS_SRGB?mix(COLOR.rgb*12.92,1.055*pow(COLOR.rgb,vec3(1./2.4))-.055,greaterThan(COLOR.rgb,vec3(.00313))):COLOR.rgb;
 if(COLOR.a<.12){
  vec2 uv=vec2(atan(local.z+.001,local.x+.001)/TAU,local.y*.52);
  float bark=dot(texture(bark_texture,uv).rgb,vec3(.27,.60,.13));
  tint*=clamp(.76+bark*.95,.79,1.18);
 } else if(COLOR.a>.5){
  float aa=max(.007,fwidth(UV.y));
  float vein=(1.-smoothstep(.006,.022+aa,abs(UV.y-.5)))*sin(PI*clamp(UV.x,0.,1.));
  tint*=1.+vein*.16;
 }
 NORMAL=normalize(face_normal);
 bool peel=COLOR.a>.30 && COLOR.a<.40;
 if(peel){
  // The peel varies at close range; screen-space filtering keeps distant fruit calm.
  vec3 rind=local*186.;
  float pore=sin(rind.x)*sin(rind.y+1.1)*sin(rind.z+.62);
  float detail=1.-smoothstep(.2,1.8,length(fwidth(rind)));
  tint*=1.+.047*pore*detail;
 }
 ALBEDO=tint;
 SPECULAR=peel ? .40 : 0.;
 BACKLIGHT=tint*.24*step(.5,COLOR.a);
 ROUGHNESS=peel ? .40 : .83;
}
