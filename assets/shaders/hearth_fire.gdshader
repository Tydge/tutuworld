shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
varying float seed;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return noise(p)*.57+noise(p*2.1+7.3)*.28+noise(p*4.3-3.7)*.15;}
void vertex(){seed=COLOR.r*19.7;float h=1.0-UV.y;VERTEX.x+=sin(TIME*2.7+h*5.0+seed)*.035*h*h;}
void fragment(){
 vec2 p=vec2(UV.x-.5,1.0-UV.y);
 float flutter=fbm(vec2(p.x*5.7+seed,p.y*4.3-TIME*1.65));
 float curl=sin(p.y*5.4-TIME*2.2+seed)*.07*p.y+sin(TIME*3.1+seed)*.025;
 float width=.50*pow(max(0.0,1.0-p.y),.75);
 float field=width-abs(p.x+curl)+(flutter-.5)*.24;
 float aa=max(fwidth(field),.012);
 float mask=smoothstep(-aa,.045+aa,field)*smoothstep(0.0,.075,p.y)*(1.0-smoothstep(.86,1.0,p.y));
 float core=clamp(field*4.0+(1.0-p.y)*.23,0.0,1.0);
 vec3 color=mix(vec3(1.0,.20,.025),vec3(1.0,.64,.12),smoothstep(.08,.62,core));
 color=mix(color,vec3(1.0,.91,.53),smoothstep(.58,.98,core)*(1.0-p.y*.5));
 ALBEDO=color;EMISSION=color*.65;ALPHA=mask*(.57+.17*flutter);
}
