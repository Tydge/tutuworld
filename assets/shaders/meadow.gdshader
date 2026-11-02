shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 meadow_color : source_color = vec4(0.25, 0.55, 0.23, 1.0);
#include "res://assets/shaders/lawn_surface.gdshaderinc"
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 vec2 p=world_pos.xz;
 float patches=noise(p*.65)*.55+noise(p*2.8)*.3+noise(p*19.0)*.15;
 ALBEDO=lawn_albedo(p,patches);
 ROUGHNESS=1.0;
}
