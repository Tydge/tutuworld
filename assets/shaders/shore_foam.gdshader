shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void fragment(){
 float wave=fract(UV.y-TIME*.055+sin(UV.x*73.0)*.025);
 float line=(1.0-smoothstep(.015,.10,abs(wave-.48)))*.46;
 float lace=sin(UV.x*270.0+sin(UV.x*37.0)*3.0)*.5+.5;
 float edge=smoothstep(.0,.12,UV.y)*(1.0-smoothstep(.80,1.0,UV.y));
 ALBEDO=vec3(.84,.94,.94);
 ALPHA=line*(.55+lace*.45)*edge;
}
