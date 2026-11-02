shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec4 sea_color : source_color = vec4(.12,.48,.70,1);
uniform float daylight=1.;
varying vec3 p;
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 v){vec2 i=floor(v),f=fract(v);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void vertex(){
 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 VERTEX.y+=.008*sin(p.z*3.1+p.x*1.7-TIME*1.8);
}
void fragment(){
 float width=3.05+smoothstep(28.,58.,p.z)*6.;float bank=clamp(abs(p.x-sin(p.z*.07)*2.)/width,0.,1.);
 float n=noise(p.xz*.8-vec2(0,TIME*.28));
 vec3 deep=vec3(.035,.20,.23),shallow=vec3(.11,.31,.26);
 vec3 base=mix(deep,shallow,pow(bank,3.));
 float lines=sin(p.z*8.7-p.x*1.9-TIME*3.+n*2.);
 float detail=pow(max(0.,lines),20.)*smoothstep(.48,.72,n);
 float shore=smoothstep(.88,1.,bank)*noise(p.xz*5.-vec2(0,TIME*.3));
 NORMAL=normalize((VIEW_MATRIX*vec4(vec3(.025*cos(p.x*3.2+p.z-TIME*1.3),1.,.035*cos(p.z*4.1-p.x-TIME*1.8)),0)).xyz);
 float fresnel=pow(1.-max(dot(NORMAL,VIEW),0.),4.);
 ALBEDO=mix(base,vec3(.21,.36,.40),fresnel*.28)+vec3(.12,.16,.15)*(detail*.14+shore*.12);
 float outlet=smoothstep(48.,59.5,p.z);
 float shallow_sea=1.-smoothstep(54.,72.,length(vec2(p.x,p.z/.88)));
 vec3 sea=mix(sea_color.rgb,sea_color.rgb*vec3(.72,1.16,1.13),shallow_sea*.42);
 float wave=sin(p.x*.72+p.z*.31+sin(p.z*.38-TIME*.18)*1.6+TIME*.28);
 float glint=smoothstep(.92,.99,wave)*smoothstep(.38,.9,sin(p.z*1.65-p.x*.27+TIME*.42));
 sea+=vec3(.12,.20,.22)*(glint*.22+sin(p.x*.15+p.z*.10+TIME*.19)*.018)*(.18+daylight*.82);
 ALBEDO*=1.-outlet;EMISSION=sea*outlet;
 ROUGHNESS=mix(.27,1.,outlet);SPECULAR=.45*(1.-outlet);
}
