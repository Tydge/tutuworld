shader_type spatial;
render_mode specular_disabled, cull_disabled;
uniform bool jet=false;
uniform vec4 water_color : source_color=vec4(.25,.66,.73,1);
void fragment(){
 vec2 p=UV-.5;
 float rings=sin(length(p)*95.0-TIME*2.7)+sin(p.x*39.0+p.y*23.0+TIME*.8)*.25;
 float flow=sin(UV.y*62.0-TIME*8.0)+sin(UV.y*113.0-TIME*12.0)*.3;
 float glint=smoothstep(.58,1.0,jet?flow:rings);
 ALBEDO=mix(water_color.rgb,vec3(.72,.90,.92),glint*(jet?.7:.24));
 EMISSION=ALBEDO*.09;
 ROUGHNESS=.25;
}
