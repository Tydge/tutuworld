shader_type spatial;
render_mode diffuse_burley,cull_back,depth_draw_never;
#include "res://assets/shaders/painted_water.gdshaderinc"
void vertex(){water_world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;water_base_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 n=ripple_at(water_world.xz);NORMAL=normalize((VIEW_MATRIX*vec4(n,0.)).xyz);
 float thickness=water_thickness(SCREEN_UV,INV_PROJECTION_MATRIX,VERTEX.z);
 float fresnel=pow(1.-clamp(dot(NORMAL,VIEW),0.,1.),4.);
 float bank=abs(UV.x*2.-1.);
 float foam=(1.-smoothstep(.10,.65,thickness))*smoothstep(.60,.85,clamp(.65+(n.x+n.z)*1.5,0.,1.));
 ALBEDO=water_tint(thickness,fresnel)+vec3(.45,.57,.49)*foam*.26;
 ROUGHNESS=mix(.18,.31,smoothstep(30.,110.,length(VERTEX)));SPECULAR=.68;
 ALPHA=clamp(mix(.31,.93,1.-exp(-thickness*.38))+fresnel*.38+foam*.26,.26,.995);
}
