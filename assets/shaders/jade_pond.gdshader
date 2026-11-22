shader_type spatial;
render_mode cull_disabled;
uniform sampler2D ripples:hint_normal,repeat_enable,filter_linear_mipmap;
uniform vec4 dye:source_color=vec4(.15,.33,.30,1.);
uniform sampler2D stones:source_color,repeat_enable,filter_linear_mipmap;
varying vec3 pos;
void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	vec2 p=pos.xz;
	vec2 waves=(texture(ripples,p*.38+vec2(TIME*.017,0.)).rg+texture(ripples,p*.57-vec2(.01,.013)*TIME).rg)*.5;
	float sky=pow(1.-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.,1.),2.);
	float shallow=1.-smoothstep(.0,.37,UV2.x);
	vec3 bed=texture(stones,p*.69+(waves-.5)*.023).rgb*vec3(.31,.48,.37);
	vec3 under=mix(dye.rgb*(.78+waves.x*.28),bed,shallow*.81);
	ALBEDO=mix(under,vec3(.105,.208,.218),sky*.35);
	NORMAL_MAP=vec3(waves,1.);NORMAL_MAP_DEPTH=.16;ROUGHNESS=.49;METALLIC=.0;SPECULAR=.31;
}
