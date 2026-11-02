shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
varying float blade_height;
varying vec3 world;
vec3 linear_color(vec3 c){return mix(pow((c+vec3(.055))/1.055,vec3(2.4)),c/12.92,lessThan(c,vec3(.04045)));}
void vertex(){
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 blade_height=UV.y;
 float sway=sin(TIME*1.35+world.x*.64+world.z*.43)*.026+sin(TIME*2.15+world.z)*.012;
 VERTEX.x+=sway*UV.y*UV.y;
 VERTEX.z+=sway*.55*UV.y;
}
void fragment(){
 vec3 col=OUTPUT_IS_SRGB?COLOR.rgb:linear_color(COLOR.rgb);
 ALBEDO=col*mix(.72,1.12,blade_height);
 NORMAL=normalize(mix(NORMAL,vec3(0.,0.,1.),.16));
 ROUGHNESS=1.;BACKLIGHT=col*.20;
}
