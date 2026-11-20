shader_type spatial;
render_mode diffuse_burley;
uniform int region=0;
uniform vec4 cream : source_color=vec4(.98,.97,.94,1);
uniform vec4 ginger : source_color=vec4(.87,.635,.42,1);
uniform vec4 grey : source_color=vec4(.58,.56,.55,1);
varying vec3 p;
void vertex(){p=VERTEX;}
void fragment(){
 vec3 fur=cream.rgb;
 if(region==2 && p.z<-.05){
  float orange_patch=pow((p.x+.25)/1.12,2.0)+pow((p.y-.60)/.95,2.0)+pow((p.z+.70)/.78,2.0);
  float grey_patch=pow((p.x-.83)/1.02,2.0)+pow((p.y+.05)/.99,2.0)+pow((p.z+.70)/.77,2.0);
  if(orange_patch<1.0) fur=ginger.rgb;
  if(grey_patch<1.0) fur=grey.rgb;
 }
 ALBEDO=fur;ROUGHNESS=.94;SPECULAR=.18;
}
