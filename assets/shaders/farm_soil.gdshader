shader_type spatial;
render_mode specular_disabled;
uniform vec4 soil_color : source_color=vec4(.58,.36,.19,1);
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float grain=noise(world_pos.xz*35.0);
 float mottling=noise(world_pos.xz*2.3)*.6+noise(world_pos.xz*9.0)*.4;
 ALBEDO=soil_color.rgb*(.87+mottling*.23)+(grain-.5)*.025;
 ROUGHNESS=1.0;
}
