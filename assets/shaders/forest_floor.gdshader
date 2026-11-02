shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 forest_color:source_color=vec4(.322,.635,.255,1.);
uniform vec4 path_color:source_color=vec4(.682,.533,.341,1.);
#include "res://assets/shaders/lawn_surface.gdshaderinc"
varying vec3 p;
varying vec3 world_normal;
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 v){vec2 i=floor(v);vec2 f=fract(v);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
 float west=abs(p.x-(-8.-clamp(32.-p.z,0.,22.)*.4));
 if(p.z>31.) west=abs(p.x-mix(-8.,-13.,smoothstep(31.,46.,p.z)));
 float north=min(abs(p.x+18.),abs(p.x-22.));
 float crosspath=abs(p.z-5.);
 float pathdist=min(west,min(p.z<12.?north:100.,abs(p.x)<27.?crosspath:100.));
 if(p.x>10. && p.x<24.) pathdist=min(pathdist,abs(p.z+29.));
 float patch=noise(p.xz*.7)*.6+noise(p.xz*4.)*.4;
 vec3 lawn=lawn_albedo(p.xz,patch);
 vec3 earth=path_color.rgb*(.92+noise(p.xz*2.)*.17);
 float path=1.-smoothstep(1.15+patch*.4,1.65+patch*.5,pathdist);
 vec3 color=mix(lawn,earth,path*.99);
 color=mix(color,vec3(.49,.40,.25),smoothstep(48.,58.,p.z)*.85);
 color=mix(vec3(.39,.32,.21),color,smoothstep(.45,.86,normalize(world_normal).y));
 ALBEDO=color*(.985+hash(floor(p.xz*80.))*.025);ROUGHNESS=1.;
}
