shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 stone_color:source_color=vec4(.67,.57,.43,1.);
uniform vec4 moss_color:source_color=vec4(.39,.55,.32,1.);
varying vec3 p;
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float strata=sin(p.y*22.+sin(p.x*.8)*.7)*.014+sin(p.x*8.+p.y*3.)*.012;
 float cap=smoothstep(.74,.97,fract(p.y*.5)+sin(p.x*1.8)*.06);
 float mottling=sin(p.x*2.2+sin(p.y*4.))*sin(p.y*3.8)*.035;
 ALBEDO=mix(stone_color.rgb*(1.+strata+mottling),moss_color.rgb,cap*.6);ROUGHNESS=1.;
}
