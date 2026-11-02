shader_type spatial;
render_mode diffuse_burley;
uniform int region=0;
uniform vec4 cream : source_color=vec4(.98,.97,.94,1);
uniform vec4 ginger : source_color=vec4(.81,.60,.39,1);
uniform vec4 grey : source_color=vec4(.52,.51,.49,1);
varying vec3 p;
varying float ear_mask;
void vertex(){p=VERTEX;ear_mask=COLOR.r;}
void fragment(){
 vec3 fur=cream.rgb;
 if(region==1){
  float crown_patch=pow((p.x+.015)/.65,2.0)+pow((p.y-.84)/.74,2.0);
  if(crown_patch<1.0 && ear_mask<.90) fur=(p.x<-.02+.07*(p.y-.5)) ? ginger.rgb : grey.rgb;
 }else if(region==2 && p.z<-.05){
  float orange_patch=pow((p.x+.25)/1.12,2.0)+pow((p.y-.60)/.95,2.0)+pow((p.z+.70)/.78,2.0);
  float grey_patch=pow((p.x-.83)/1.02,2.0)+pow((p.y+.05)/.99,2.0)+pow((p.z+.70)/.77,2.0);
  if(orange_patch<1.0) fur=ginger.rgb;
  if(grey_patch<1.0) fur=grey.rgb;
 }
 ALBEDO=fur;ROUGHNESS=.94;SPECULAR=.18;
}
