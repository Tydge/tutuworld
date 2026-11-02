shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley;
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 v){vec2 i=floor(v),f=fract(v);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void vertex(){VERTEX.z+=sin(UV.x*57.+UV.y*9.-TIME*4.)*.012*sin(UV.y*3.14159);}
void fragment(){
 float lanes=noise(vec2(UV.x*48.,.7));
 float flow=noise(vec2(UV.x*29.,UV.y*4.-TIME*2.1));
 float whitewater=smoothstep(.30,.78,lanes)*.52+flow*.24+smoothstep(.65,1.,UV.y)*.14;
 ALBEDO=mix(vec3(.10,.37,.39),vec3(.65,.83,.78),whitewater);
 float edge=smoothstep(0.,.035,UV.x)*(1.-smoothstep(.965,1.,UV.x));
 ALPHA=edge*(.72+whitewater*.26);
 ROUGHNESS=.33;SPECULAR=.38;
}
