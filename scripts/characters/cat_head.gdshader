shader_type spatial;
render_mode diffuse_burley;
uniform vec4 cream : source_color=vec4(.98,.97,.94,1);
uniform vec4 ginger : source_color=vec4(.87,.635,.42,1);
uniform vec4 grey : source_color=vec4(.58,.56,.55,1);
varying vec3 p;
varying float ear_mask;
void vertex(){p=VERTEX;ear_mask=COLOR.r;}
void fragment(){
	vec2 crown=vec2((p.x*.70+.006)/.331,(p.y*.56-.542)/.448);
	float edge=dot(crown,crown);
	vec3 split=mix(ginger.rgb,grey.rgb,smoothstep(-.012,.012,p.x+.035-.07*p.y));
	float painted=(1.0-smoothstep(.99,1.01,edge))*(1.0-smoothstep(.40,.90,ear_mask));
	ALBEDO=mix(cream.rgb,split,painted);
	ROUGHNESS=.94;
	SPECULAR=.18;
}
