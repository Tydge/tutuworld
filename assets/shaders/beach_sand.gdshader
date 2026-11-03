shader_type spatial;
render_mode specular_disabled, cull_disabled;
uniform vec4 dry_sand : source_color=vec4(.89,.78,.59,1);
uniform vec4 wet_sand : source_color=vec4(.66,.53,.36,1);
uniform sampler2D sand_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 float grain=noise(p*5.5);
 float ripple=sin(p.y*4.0+sin(p.x*.8)*.6);
 vec3 base=mix(wet_sand.rgb,dry_sand.rgb,smoothstep(-1.5,-.05,world_pos.y));
 float texture_grain=dot(texture(sand_texture,p*.48).rgb,vec3(.333333));
 float damp=1.-smoothstep(-1.35,-.20,world_pos.y);
 ALBEDO=base*(.97+ripple*.012)*mix(1.,clamp(texture_grain/.59,.76,1.20),.65)+(grain-.5)*.009;
 ROUGHNESS=mix(.97,.56,damp);
}
