shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform vec4 sea_color : source_color = vec4(.12,.48,.70,1);
uniform vec4 horizon_color : source_color = vec4(.63,.82,.94,1);
uniform float daylight=1.0;
varying vec3 world_pos;
#include "res://assets/shaders/ocean_surface.gdshaderinc"
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 float range_=length(VERTEX);
 float shore_radius=length(vec2(p.x,p.y/.88));
 vec3 water=ocean_albedo(p,sea_color.rgb,daylight);
 vec3 wave_normal=normalize(vec3(.035*cos(p.x*.53+p.y*.28-TIME*.7),1.,.045*cos(p.y*.61-p.x*.2+TIME*.5)));
 vec3 view_normal=normalize((VIEW_MATRIX*vec4(wave_normal,0.)).xyz);
 float fresnel=pow(1.-clamp(dot(view_normal,VIEW),0.,1.),4.);
 water=mix(water,horizon_color.rgb,fresnel*.23);
 ALBEDO=mix(water,horizon_color.rgb,smoothstep(95.,330.,range_));
}
