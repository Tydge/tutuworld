shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec4 sea_color : source_color = vec4(.12,.48,.70,1);
uniform float daylight=1.;
varying vec3 p;
#include "res://assets/shaders/ocean_surface.gdshaderinc"
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 v){vec2 i=floor(v),f=fract(v);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void vertex(){
 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 VERTEX.y+=.008*sin(p.z*3.1+p.x*1.7-TIME*1.8);
}
void fragment(){
 float width=3.05+smoothstep(28.,58.,p.z)*6.;float bank=clamp(abs(p.x-sin(p.z*.07)*2.)/width,0.,1.);
 float n=noise(p.xz*.8-vec2(0,TIME*.28));
 vec3 deep=vec3(.035,.23,.255),shallow=vec3(.17,.37,.29);
 vec3 base=mix(deep,shallow,pow(bank,3.));
 float lines=sin(p.z*8.7-p.x*1.9-TIME*3.+n*2.);
 float detail=smoothstep(.88-fwidth(lines),.99+fwidth(lines),lines)*smoothstep(.48,.72,n);
 float shore=smoothstep(.84,.98,bank)*(0.5+0.5*sin(p.z*9.-TIME*2.+n*3.));
 NORMAL=normalize((VIEW_MATRIX*vec4(vec3(.025*cos(p.x*3.2+p.z-TIME*1.3),1.,.035*cos(p.z*4.1-p.x-TIME*1.8)),0)).xyz);
 float fresnel=pow(1.-max(dot(NORMAL,VIEW),0.),4.);
 float caustic=pow(max(0.,sin(p.x*6.2+p.z*4.6+TIME*.7)*sin(p.z*5.1-p.x*2.5-TIME*.5)),4.);
 ALBEDO=mix(base,vec3(.26,.44,.46),fresnel*.4)+vec3(.18,.24,.20)*(detail*.28+shore*.20+caustic*pow(bank,2.)*.10);
 float outlet=smoothstep(48.,59.5,p.z);
 vec3 sea=ocean_albedo(p.xz,sea_color.rgb,daylight);
 ALBEDO*=1.-outlet;EMISSION=sea*outlet;
 ROUGHNESS=mix(.27,1.,outlet);SPECULAR=.45*(1.-outlet);
}
