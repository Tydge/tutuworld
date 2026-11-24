shader_type spatial;
render_mode cull_disabled;
uniform sampler2DArray skins:source_color,repeat_enable,filter_linear_mipmap_anisotropic;
uniform float warmth=.0;
#include "res://assets/shaders/jade_paper_light.gdshaderinc"
varying vec2 street;
void vertex(){street=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment(){
	vec2 dx=dFdx(UV),dy=dFdy(UV);
	int mode=int(floor(UV2.x+.5));vec3 colour=COLOR.rgb;
	if(mode>0)colour*=textureGrad(skins,vec3(UV,float(mode-1)),dx,dy).rgb;
	else if(mode==-1){colour*=mix(vec3(.55,.405,.236),vec3(.77,.43,.14),warmth);EMISSION=jade_paper_light(UV,street,warmth);}
	else if(mode==-2){EMISSION=vec3(.68,.22,.046)*warmth;}
	ALBEDO=colour;ROUGHNESS=UV2.y;
}
