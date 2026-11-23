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
uniform sampler2D timber:source_color,repeat_enable,filter_linear_mipmap;
uniform float warmth=.0;
#include "res://assets/shaders/jade_paper_light.gdshaderinc"
varying vec2 street;
void vertex(){street=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment(){
	vec2 dx=dFdx(UV),dy=dFdy(UV);
	int mode=int(floor(UV2.x+.5));vec3 colour=COLOR.rgb;
	if(mode==1)colour*=textureGrad(plaster,UV,dx,dy).rgb;
	else if(mode==2)colour*=textureGrad(wood,UV,dx,dy).rgb;
	else if(mode==3)colour*=textureGrad(tile,UV,dx,dy).rgb;
	else if(mode==4)colour*=textureGrad(masonry,UV,dx,dy).rgb;
	else if(mode==5)colour*=textureGrad(frieze,UV,dx,dy).rgb;
	else if(mode==6)colour*=textureGrad(screen,UV,dx,dy).rgb;
	else if(mode==7)colour*=textureGrad(crane,UV,dx,dy).rgb;
	else if(mode==8)colour*=textureGrad(relief,UV,dx,dy).rgb;
	else if(mode==9){colour*=mix(vec3(.55,.405,.236),vec3(.77,.43,.14),warmth);EMISSION=jade_paper_light(UV,street,warmth);}
	else if(mode==10){EMISSION=vec3(.68,.22,.046)*warmth;}
	else if(mode==11)colour*=textureGrad(amber,UV,dx,dy).rgb;
	else if(mode==12)colour*=textureGrad(timber,UV,dx,dy).rgb;
	ALBEDO=colour;ROUGHNESS=.86;
}
