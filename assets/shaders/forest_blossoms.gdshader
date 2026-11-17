shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
#include "res://assets/shaders/vegetation_noise.gdshaderinc"
uniform vec4 dye_multiplier:source_color=vec4(1.);
uniform vec2 plant_fade=vec2(0.);
varying vec4 tint;
varying float plant_visibility;
vec3 linear_color(vec3 c){return mix(pow((c+vec3(.055))/1.055,vec3(2.4)),c/12.92,lessThan(c,vec3(.04045)));}
void vertex(){vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;VERTEX.x+=sin(TIME*1.35+p.x*.7+p.z*.4)*.018*UV.y;tint=COLOR;plant_visibility=plant_fade.y>0.?1.-smoothstep(plant_fade.x,plant_fade.y,distance(p,MAIN_CAM_INV_VIEW_MATRIX[3].xyz)):1.;}
void fragment(){
 if(plant_visibility<.999 && vegetation_noise(FRAGCOORD.xy)>=plant_visibility)discard;
 ALBEDO=(OUTPUT_IS_SRGB?tint.rgb:linear_color(tint.rgb))*dye_multiplier.rgb;ROUGHNESS=.94;BACKLIGHT=ALBEDO*.10;
}
