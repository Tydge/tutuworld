shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 stone_color : source_color = vec4(0.49,0.56,0.53,1.0);
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz*1.08; p.x+=mod(floor(p.y),2.0)*.5;
 vec2 cell=floor(p); vec2 f=fract(p);
 float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
 float aa=max(fwidth(edge),.001);
 float seam=smoothstep(.014-aa,.032+aa,edge);
 float grain=hash(floor(world_pos.xz*85.0));
 vec3 stone=stone_color.rgb*(.91+hash(cell)*.17)+(grain-.5)*.014;
 ALBEDO=mix(stone_color.rgb*.58,stone,seam);
 ROUGHNESS=.96;
}
