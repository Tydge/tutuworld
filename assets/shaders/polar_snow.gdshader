shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform bool mountains = false;
uniform bool town_paths = false;
uniform bool coastal_ridges = false;
uniform vec4 snow_color : source_color = vec4(.81,.89,.97,1.);
uniform sampler2D snow_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rock_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 p=world_pos.xz;
 float broad=noise(p*.075)*.65+noise(p*.28)*.35;
 float grain=noise(p*19.);
 float ripple=sin(p.x*2.6+sin(p.y*.56)*2.+broad*3.);
 vec3 tex=texture(snow_texture,p*.48).rgb;
 float detail=dot(tex,vec3(.333333));
 vec3 snow=snow_color.rgb*mix(.79,1.02,clamp(detail/.78,.0,1.));
 snow*=mix(.94,1.03,broad);
 if(town_paths){
  float ns=length(vec2(p.x+79.,max(abs(p.y-6.)-98.,0.)));
  float cross=length(vec2(max(abs(p.x+70.)-48.,0.),p.y-16.));
  float shop=length(vec2(max(abs(p.x+80.)-29.,0.),p.y+12.));
  vec2 ab=vec2(25.,-44.);float u=clamp(dot(p-vec2(-104.,118.),ab)/dot(ab,ab),0.,1.);
  float harbor=length(p-(vec2(-104.,118.)+ab*u));
  float path=1.-smoothstep(1.5,3.2,min(min(ns,cross),min(shop,harbor))+(broad-.5)*.6);
  snow=mix(snow,snow*vec3(.80,.86,.91),path*.57);
 }
 bool rim=coastal_ridges && length(p/vec2(178.,158.))>.90;
 if(mountains || rim){
  float ribs=noise(p*.055+vec2(world_pos.y*.075,0.));
  float striation=sin(world_pos.y*.50+noise(p*.07)*3.);
  float gullies=pow(abs(sin(world_pos.y*.058+p.x*.036+noise(p*.014)*3.)),5.);
  float cover=smoothstep(.72,1.06,world_normal.y-gullies*.38+(ribs-.5)*.26+striation*.025);
  if(rim)cover=smoothstep(.30,.79,world_normal.y-gullies*.12+(ribs-.5)*.18);
  vec3 weights=pow(abs(world_normal),vec3(4.));weights/=max(dot(weights,vec3(1.)),.001);
  vec3 stone=texture(rock_texture,world_pos.yz*.06).rgb*weights.x+texture(rock_texture,p*.06).rgb*weights.y+texture(rock_texture,world_pos.xy*.06).rgb*weights.z;
  float slate=dot(stone,vec3(.333333));
  vec3 rock=mix(vec3(.10,.17,.24),vec3(.30,.37,.44),slate*1.1+broad*.2);
  snow=mix(rock,snow,cover);
 }
 ALBEDO=snow;
 ROUGHNESS=.76+grain*.18;
 SPECULAR=.32;
 // Wind combing and sub-pixel crystals; derivatives prevent sparkling aliasing.
 float dx=dot(texture(snow_texture,p*.48+vec2(.002,0)).rgb-tex,vec3(.333333));
 float dz=dot(texture(snow_texture,p*.48+vec2(0,.002)).rgb-tex,vec3(.333333));
 NORMAL_MAP=normalize(vec3(-dx*.8,-dz*.8+ripple*.009,1.))*.5+.5;
 NORMAL_MAP_DEPTH=.20;
 float crystal=pow(grain,32.)*.012/(1.+length(fwidth(p))*8.);
 EMISSION=vec3(.65,.81,1.)*crystal;
}
