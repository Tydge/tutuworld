shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 bark_color:source_color=vec4(.86,.85,.76,1);
void fragment(){
 vec2 p=UV*vec2(14.,6.);
 float row=floor(p.y);vec2 q=fract(p+vec2(sin(row*7.1)*3.,0.))-.5;
 float mark=(1.-smoothstep(.025,.07,abs(q.y)))*(1.-smoothstep(.15,.42,abs(q.x)));
 float thin=sin(UV.y*160.)*.018+sin(UV.x*83.+UV.y*22.)*.008;
 ALBEDO=mix(bark_color.rgb*(1.+thin),vec3(.22,.24,.23),mark*.72);ROUGHNESS=1.;
}
