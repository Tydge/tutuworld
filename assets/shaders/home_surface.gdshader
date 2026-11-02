shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color=vec4(1.0);
uniform int pattern=0;
uniform bool vertex_tint=false;
uniform float opacity=1.0;
uniform float cut_base_height=-100.0;

uniform float roughness_value=.9;
varying vec3 p;
varying vec3 local_pos;
varying vec3 local_normal;
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float bayer(vec2 v){vec2 q=mod(floor(v),4.0);return mod(mod(q.x,2.0)*2.0+mod(q.y,2.0)*3.0,4.0)*.25+mod(floor(q.x*.5)*2.0+floor(q.y*.5)*3.0,4.0)*.0625;}
vec3 display_color(vec3 c){return mix(1.055*pow(max(c,vec3(0.0)),vec3(1.0/2.4))-.055,c*12.92,lessThan(c,vec3(.0031308)));}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;local_pos=VERTEX;local_normal=NORMAL;}
void fragment(){
 float visibility=(p.y<cut_base_height)?1.0:opacity;
 if(visibility<.001 || (visibility<.999 && bayer(FRAGCOORD.xy)>=visibility)) discard;
 vec3 vertex_color=OUTPUT_IS_SRGB?display_color(COLOR.rgb):COLOR.rgb;
 vec3 base=tint.rgb*(vertex_tint?vertex_color:vec3(1.0));
 vec3 color=base;
 float grain=(hash(floor(p.xz*110.0))-.5)*.014;
 if(pattern==1){
  vec2 uv=local_pos.xz;float row=floor(uv.y*3.2);uv.x+=mod(row,2.0)*1.05;
  vec2 f=fract(uv*vec2(.48,3.2));float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
  float aa=max(fwidth(edge),.001);float seam=smoothstep(.006-aa,.014+aa,edge);
  float streak=sin(uv.x*24.0+sin(uv.x*2.0+row)*2.8+uv.y*135.0)*.012;
  color*=.94+hash(vec2(floor(uv.x*.48),row))*.11+streak+grain;
  color=mix(base*.72,color,seam);
 }else if(pattern==2){
  vec2 uv=vec2(abs(local_pos.x)*2.2,local_pos.z*1.6);uv.y+=mod(floor(uv.x),2.0)*.5;
  vec2 f=fract(uv);float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
  float aa=max(fwidth(edge),.002);float seam=smoothstep(.015-aa,.04+aa,edge);
  color*=.94+hash(floor(uv))*.10+sin(f.y*3.14159)*.035;
  color=mix(base*.69,color,seam);
 }else if(pattern==3){
  vec2 uv=(abs(local_normal.z)>.6?local_pos.xy:local_pos.zy)*vec2(2.0,1.3);
  float row=floor(uv.y);uv.x+=mod(row,2.0)*.5;vec2 f=fract(uv);
  float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
  color*=mix(.74,.97+hash(floor(uv))*.08,smoothstep(.025,.06,edge));
 }else{color*=1.0+grain*.65;}
 ALBEDO=color;ROUGHNESS=roughness_value;SPECULAR=.22;
}
