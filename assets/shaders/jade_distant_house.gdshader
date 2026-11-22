shader_type spatial;
render_mode cull_disabled;
uniform sampler2D plaster:source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D wood:source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D tile:source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D masonry:source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D frieze:source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D screen:source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D crane:source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D relief:source_color,repeat_enable,filter_linear_mipmap;
uniform sampler2D amber:source_color,repeat_enable,filter_linear_mipmap;
uniform float warmth=.0;
void fragment(){
	int mode=int(floor(UV2.x+.5));vec3 colour=COLOR.rgb;
	if(mode==1)colour*=texture(plaster,UV).rgb;
	else if(mode==2)colour*=texture(wood,UV).rgb;
	else if(mode==3)colour*=texture(tile,UV).rgb;
	else if(mode==4)colour*=texture(masonry,UV).rgb;
	else if(mode==5)colour*=texture(frieze,UV).rgb;
	else if(mode==6)colour*=texture(screen,UV).rgb;
	else if(mode==7)colour*=texture(crane,UV).rgb;
	else if(mode==8)colour*=texture(relief,UV).rgb;
	else if(mode==9){colour*=mix(vec3(.55,.405,.236),vec3(.77,.43,.14),warmth);EMISSION=vec3(.93,.46,.13)*warmth*.54;}
	else if(mode==10){EMISSION=vec3(.68,.22,.046)*warmth;}
	else if(mode==11)colour*=texture(amber,UV).rgb;
	ALBEDO=colour;ROUGHNESS=.86;
}
