shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;
uniform sampler2D flame_atlas : source_color,filter_linear_mipmap,repeat_disable;
void fragment(){
 float phase=TIME*11.+dot(MODEL_MATRIX[3].xz,vec2(.31,.17));
 float frame=mod(floor(phase),16.);float next=mod(frame+1.,16.);
 vec2 cell=vec2(mod(frame,4.),floor(frame/4.));vec2 cell2=vec2(mod(next,4.),floor(next/4.));
 vec2 uv=clamp(UV,vec2(.018),vec2(.982));
 vec4 a=texture(flame_atlas,(cell+uv)*.25);vec4 b=texture(flame_atlas,(cell2+uv)*.25);
 vec4 fire=mix(a,b,smoothstep(.0,1.,fract(phase)));
 // Reject the atlas' pale background by chroma as well as alpha. The source
 // RGBA remains untouched; only warm flame/white-yellow core contributes.
 float warm=max(0.,fire.r-fire.b*1.18);
 float alpha=smoothstep(.06,.29,warm)*smoothstep(.08,.55,fire.a)*fire.a;
 ALBEDO=fire.rgb;EMISSION=fire.rgb*1.6;ALPHA=alpha*.84;
}
