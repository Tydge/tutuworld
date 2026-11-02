shader_type spatial;
uniform int region=0;
uniform vec4 ivory:source_color=vec4(.96,.95,.91,1.0);
uniform vec4 charcoal:source_color=vec4(.105,.12,.135,1.0);
varying vec3 point;
void vertex(){point=VERTEX;}
void fragment(){
 float dark=region==3?1.0:0.0;
 if(region==1){
  float side=point.x<0.0?-1.0:1.0;
  vec2 p=point.xy-vec2(side*.292,.025);
  float angle=side*.28;
  p=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*p;
  float patch=length(p/vec2(.18,.232));
  dark=(1.0-smoothstep(.98,1.035,patch))*smoothstep(.13,.43,point.z);
  vec3 ear_delta=(point-vec3(side*.60,.495,-.075))/vec3(.215,.255,.205);
  dark=max(dark,1.0-smoothstep(.94,1.035,length(ear_delta)));
 }
 if(region==2) dark=smoothstep(.27,.33,point.y);
 // Subtle matte fibre grain, without transparent fur shells or extra draws.
 float fibre=sin(point.x*214.0+sin(point.z*153.0))*sin(point.y*196.0+point.z*67.0);
 float fade=1.0-smoothstep(.015,.055,length(fwidth(point)));
 ALBEDO=mix(ivory.rgb,charcoal.rgb,dark)*(1.0+fibre*.012*fade);
 ROUGHNESS=.96;SPECULAR=.15;
}
