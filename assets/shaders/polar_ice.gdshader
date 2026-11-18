shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 wp;
varying vec3 wn;
uniform vec4 horizon_color : source_color = vec4(.7,.65,.8,1.);
uniform float daylight = 1.;
uniform sampler2D reflection_texture : source_color,filter_linear,repeat_disable;
uniform bool reflection_ready=false;
uniform mat4 reflection_matrix;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
vec2 rand2(vec2 p){return vec2(hash(p),hash(p+31.7));}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fracture(vec2 p){
 vec2 cell=floor(p),f=fract(p),nearest=vec2(0.),delta=vec2(0.);float md=10.;
 for(int j=-1;j<=1;j++)for(int i=-1;i<=1;i++){
  vec2 g=vec2(float(i),float(j));vec2 r=g+rand2(cell+g)*.8-f;float d=dot(r,r);
  if(d<md){md=d;nearest=g;delta=r;}
 }
 float edge=10.;
 for(int j=-1;j<=1;j++)for(int i=-1;i<=1;i++){
  vec2 g=nearest+vec2(float(i),float(j));vec2 r=g+rand2(cell+g)*.8-f;
  if(dot(r-delta,r-delta)>.0001)edge=min(edge,dot(.5*(delta+r),normalize(r-delta)));
 }
 return edge;
}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;wn=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 p=wp.xz;float n=noise(p*.083),fine=noise(p*7.);
 vec2 bend=vec2(noise(p*.32),noise(p*.32+37.))*.17;
 float edge=fracture(p*.095+bend);
 float aa=max(fwidth(edge),.0007);
 float crack=1.-smoothstep(.0005,.0025+aa,edge);
 float halo=1.-smoothstep(.002,.018,edge);
 float snow= smoothstep(.68,.85,noise(p*.045+noise(p*.12)))*.85;
 float shore=-21.+7.*sin(p.y*.024)+3.*sin(p.y*.065);
 snow=max(snow,1.-smoothstep(4.,14.,p.x-shore));
 vec3 blue=mix(vec3(.008,.035,.07),vec3(.028,.11,.19),n);
 blue=mix(blue,vec3(.29,.51,.64),halo*.25);
 blue=mix(blue,vec3(.58,.83,.91),crack*.43);
 ALBEDO=mix(blue,vec3(.76,.85,.94),snow);
 METALLIC=.05;
 ROUGHNESS=mix(.075+n*.045,.77,snow);
 SPECULAR=.68;
 // Opaque dielectric: sky radiance and the single shared reflection probe provide
 // reflection without transparent sorting, a second scene render or per-tile mirrors.
 NORMAL_MAP=normalize(vec3(sin(p.x*.9+sin(p.y*.7))*.016,(fine-.5)*.035,1.))*.5+.5;
 NORMAL_MAP_DEPTH=.34;
 EMISSION=vec3(.13,.34,.43)*halo*.035*daylight;
 if(reflection_ready){
  vec4 clip=reflection_matrix*vec4(wp,1.);
  vec2 uv=clip.xy/clip.w*.5+.5;uv.y=1.-uv.y;
  uv+=vec2(sin(p.x*.27+p.y*.17),sin(p.y*.36))*.00010;
  float border=smoothstep(.0,.004,min(min(uv.x,uv.y),min(1.-uv.x,1.-uv.y)));
  float fresnel=.10+.85*pow(1.-clamp(dot(NORMAL,VIEW),0.,1.),3.);
  float strength=.78*fresnel*(1.-snow)*border*step(0.,clip.w);
  vec3 reflection=texture(reflection_texture,uv).rgb;
  ALBEDO*=1.-strength;SPECULAR=mix(.68,.18,strength);
  EMISSION+=reflection*strength;
 }
}
