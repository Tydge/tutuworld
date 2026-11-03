shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform vec4 dye_multiplier:source_color=vec4(1.);
varying vec4 tint;
vec3 linear_color(vec3 c){return mix(pow((c+vec3(.055))/1.055,vec3(2.4)),c/12.92,lessThan(c,vec3(.04045)));}
void vertex(){vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;VERTEX.x+=sin(TIME*1.35+p.x*.7+p.z*.4)*.018*UV.y; tint=COLOR;}
void fragment(){ALBEDO=(OUTPUT_IS_SRGB?tint.rgb:linear_color(tint.rgb))*dye_multiplier.rgb;ROUGHNESS=.94;BACKLIGHT=ALBEDO*.10;}
