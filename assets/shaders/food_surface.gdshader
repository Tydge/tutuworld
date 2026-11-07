shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec4 tint:source_color=vec4(1.);
uniform int kind=0;
varying vec3 p;
float hash(vec3 v){return fract(sin(dot(v,vec3(127.1,311.7,74.7)))*43758.5453);}
float soft_noise(vec2 v){vec2 cell=floor(v),f=fract(v);f=f*f*(3.-2.*f);return mix(mix(hash(vec3(cell,0)),hash(vec3(cell+vec2(1,0),0)),f.x),mix(hash(vec3(cell+vec2(0,1),0)),hash(vec3(cell+vec2(1,1),0)),f.x),f.y);}
void vertex(){p=VERTEX;}
void fragment(){
 vec3 color=tint.rgb*COLOR.rgb;
 float fleck=hash(floor(p*260.));
 if(kind==0){
  float roast=sin(p.x*12.+p.z*7.)*sin(p.z*17.-p.y*11.)*.09;
  float top=smoothstep(.10,.29,p.y);
  color*=1.+roast-top*.13+(fleck-.5)*.045;
  float seam=abs(mod(p.x+p.z*.30+.195,.13)-.065);
  color=mix(color,color*1.23,smoothstep(.15,.23,p.y)*(1.-smoothstep(.005,.010,seam))*.6);
 }else if(kind==1){
  float toast=smoothstep(.58,.83,soft_noise(p.xz*48.));
  color*=1.-toast*.16+(fleck-.5)*.035;
 }else if(kind==2){
  color*=.96+sin(p.x*63.+p.z*22.)*.025+(fleck-.5)*.025;
 }else if(kind==3){color*=.988+fleck*.024;
 }else if(kind==4){color*=1.+sin(p.x*27.+p.z*19.)*sin(p.z*22.-p.x*8.)*.014;
 }else if(kind==5){color*=.97+fleck*.065;}
 ALBEDO=color;SPECULAR=.18;ROUGHNESS=kind==3?.37:(kind==4?.28:.78);
}
