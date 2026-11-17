shader_type spatial;
render_mode diffuse_burley,specular_disabled;
uniform vec4 forest_color:source_color=vec4(.44,.56,.29,1.);
uniform vec4 path_color:source_color=vec4(.66,.55,.37,1.);
uniform sampler2D lawn_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D path_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rock_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 p;
varying vec3 world_normal;
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 v){vec2 i=floor(v),f=fract(v);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 float west=-16.-clamp(64.-p.z,0.,44.)*.4+sin(p.z*.07)*1.5;
 if(p.z>62.)west=mix(-16.,-22.,smoothstep(62.,88.,p.z));
 float pathdist=abs(p.x-west);
 pathdist=min(pathdist,length(vec2(p.x-(44.+sin(p.z*.035)*2.5),max(p.z-35.,0.))));
 pathdist=min(pathdist,length(vec2(max(abs(p.x)-57.,0.),p.z-10.)));
 pathdist=min(pathdist,length(vec2(p.x-24.,max(p.z+42.,0.))));
 pathdist=min(pathdist,length(vec2(max(abs(p.x-5.5)-41.5,0.),p.z+58.)));
 float ascent=37.-(abs(p.x)-34.)*.88+3.*sin((abs(p.x)-34.)*.11);
 float end_distance=max(max(25.-abs(p.x),abs(p.x)-83.),0.);
 pathdist=min(pathdist,length(vec2(end_distance,(p.z-ascent)*.75)));
 float macro=noise(p.xz*.065);float patch=noise(p.xz*.6);
 float path=1.-smoothstep(1.30+patch*.35,2.45+macro*.45,pathdist);
 vec3 turf=texture(lawn_texture,p.xz*.36).rgb;
 float leaf_value=clamp(dot(turf,vec3(.25,.60,.15))/.23,.57,1.45);
 vec3 grass=mix(forest_color.rgb,turf*.86,.72)*mix(.88,1.12,macro);
 grass=mix(grass,grass*vec3(.87,.94,1.06),noise(p.xz*.15+18.)*.18);
 vec3 earth_detail=texture(path_texture,p.xz*.45).rgb;
 float grit=clamp(dot(earth_detail,vec3(.3,.6,.1))/.29,.62,1.38);
 vec3 earth=path_color.rgb*mix(.90,grit,.42);
 vec3 color=mix(grass,earth,path);
 float steep=1.-smoothstep(.65,.87,normalize(world_normal).y);
 vec3 rock=texture(rock_texture,p.xz*.18).rgb;
 color=mix(color,rock*vec3(.72,.77,.62),steep*.74);
 float channel=abs(p.x-sin(p.z*.035)*4.)-(6.1+smoothstep(56.,116.,p.z)*12.);
 color=mix(color,mix(vec3(.085,.11,.085),rock*.55,.50),1.-smoothstep(-2.5,.4,channel));
 ALBEDO=color;ROUGHNESS=.98;
}
