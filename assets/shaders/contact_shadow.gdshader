shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float strength=.17;
void fragment(){float d=length((UV-.5)*2.0);ALBEDO=vec3(.15,.18,.13);ALPHA=pow(max(0.0,1.0-d),1.8)*strength;}
