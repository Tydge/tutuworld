shader_type spatial;
render_mode cull_disabled,diffuse_burley,specular_disabled;
varying vec4 blade_tint;
varying float blade_height;
vec3 linear_color(vec3 c){return mix(pow((c+vec3(.055))/1.055,vec3(2.4)),c/12.92,lessThan(c,vec3(.04045)));}
void vertex(){
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 float distance_=distance(p,CAMERA_POSITION_WORLD);
 float grow=1.-smoothstep(29.,43.,distance_);
 float gust=sin(p.x*.26+p.z*.18+TIME*1.3)+.36*sin(p.z*.6-TIME*.8);
 VERTEX.y*=grow;VERTEX.x+=gust*.065*UV.y*UV.y*grow;
 blade_tint=COLOR;blade_height=UV.y;
}
void fragment(){
 if(!FRONT_FACING)NORMAL=-NORMAL;
 vec3 tint=OUTPUT_IS_SRGB?blade_tint.rgb:linear_color(blade_tint.rgb);
 ALBEDO=tint*mix(.91,1.10,blade_height);ROUGHNESS=.96;BACKLIGHT=ALBEDO*.18;
}
