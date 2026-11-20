shader_type spatial;
render_mode cull_disabled;
void vertex(){
 float a=TIME*.22+.71;
 mat2 spin=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)));
 VERTEX.xy=spin*VERTEX.xy;
 NORMAL.xy=spin*NORMAL.xy;
}
void fragment(){
 ALBEDO=OUTPUT_IS_SRGB?mix(12.92*COLOR.rgb,1.055*pow(COLOR.rgb,vec3(1./2.4))-.055,greaterThan(COLOR.rgb,vec3(.00313))):COLOR.rgb;
 ROUGHNESS=.86;
}
