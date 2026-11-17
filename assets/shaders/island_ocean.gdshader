shader_type spatial;
render_mode diffuse_burley,cull_back,depth_draw_never;
#include "res://assets/shaders/painted_water.gdshaderinc"
uniform bool valley_estuary=false;
void vertex(){water_world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;water_base_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec2 current=mix(flow,vec2(.006,-.04),valley_estuary?(1.-smoothstep(82.,117.,water_world.z)):0.);
 vec3 n=ripple_flow(water_world.xz,current);NORMAL=normalize((VIEW_MATRIX*vec4(n,0.)).xyz);
 float fresnel=pow(1.-clamp(dot(NORMAL,VIEW),0.,1.),4.);
 float thickness=water_thickness(SCREEN_UV,INV_PROJECTION_MATRIX,VERTEX.z);
 float rip=clamp(.65+(n.x+n.z)*1.5,0.,1.);
 float foam=(1.-smoothstep(.08,.55,thickness))*smoothstep(.52,.79,rip);
 ALBEDO=water_tint(thickness,fresnel)+vec3(.42,.52,.48)*foam*.35;
 float distance_=length(VERTEX);
 ROUGHNESS=mix(.17,.36,smoothstep(35.,180.,distance_));SPECULAR=.68;
 ALPHA=clamp(mix(.36,.96,1.-exp(-thickness*.29))+fresnel*.32+foam*.28,.25,.995);
}
