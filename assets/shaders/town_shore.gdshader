shader_type spatial;
render_mode diffuse_burley, specular_disabled;
#include "res://assets/shaders/lawn_surface.gdshaderinc"
uniform vec4 dry_sand:source_color=vec4(.89,.78,.59,1.);
uniform vec4 wet_sand:source_color=vec4(.66,.53,.36,1.);
uniform sampler2D sand_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world_pos;
varying float sand_mix;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;sand_mix=COLOR.a;}
void fragment(){
 vec2 p=world_pos.xz;
 float patches=noise(p*.65)*.55+noise(p*2.8)*.3+noise(p*19.)*.15;
 float beach=1.-smoothstep(.97,1.02,length(vec2(p.x/38.,(p.y-34.)/15.)));
 float transition=max(beach,smoothstep(.04,.96,sand_mix+(noise(p*3.5)-.5)*.15));
 float damp=1.-smoothstep(-1.35,-.2,world_pos.y);
 vec3 sand=mix(dry_sand.rgb,wet_sand.rgb,damp);
 float grain=dot(texture(sand_texture,p*.48).rgb,vec3(.333333));
 sand*=mix(1.,clamp(grain/.59,.76,1.20),.65);
 ALBEDO=mix(lawn_albedo(p,patches),sand,transition);
 ROUGHNESS=mix(1.,mix(.97,.56,damp),transition);
}
