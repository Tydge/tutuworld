shader_type spatial;
render_mode diffuse_burley;
varying vec3 p;
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 q){vec2 i=floor(q),f=fract(q);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){p=VERTEX;}
void fragment(){
 float n=noise(UV*vec2(23.,15.));
 float crack=pow(abs(sin(UV.y*60.+noise(UV*9.)*5.)),30.)*smoothstep(.45,.8,n);
 ALBEDO=mix(vec3(.025,.021,.018),vec3(.10,.075,.048),n);
 ROUGHNESS=.96;
 EMISSION=vec3(1.,.13,.009)*crack*(.9+.16*sin(TIME*2.4+p.x*4.));
}
