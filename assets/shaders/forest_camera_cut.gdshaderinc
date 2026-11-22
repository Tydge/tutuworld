global uniform vec4 canopy_focus;
global uniform vec3 canopy_eye;
uniform bool follow_game_camera=false;
uniform vec3 forest_focus=vec3(0.);
#include "res://assets/shaders/vegetation_noise.gdshaderinc"
uniform vec3 forest_view=vec3(0.);
uniform bool forest_cut_enabled=false;
// 0 keeps a complete silhouette (ridge / independent shadow caster).
uniform int forest_lod=0;
uniform float forest_detail_begin=64.;
uniform float forest_detail_end=104.;
varying vec3 forest_vertex;
varying flat float forest_camera_pass;
varying flat float forest_detail;
float forest_detail_weight(vec3 origin,vec3 camera){return 1.-smoothstep(forest_detail_begin,forest_detail_end,distance(origin,camera));}
bool forest_lod_discard(vec2 pixel){
 if(forest_lod==0)return false;
 float pattern=vegetation_noise(pixel);
 return forest_lod==1 ? pattern>=forest_detail : pattern<forest_detail;
}
// Resolve only the small viewing corridor. Shadow and reflection passes stay whole.
vec3 canopy_observer(){return follow_game_camera?canopy_eye:forest_view;}
bool forest_obscures(){
 if(forest_camera_pass<.5 || (follow_game_camera?canopy_focus.w<.5:!forest_cut_enabled))return false;
 vec3 focus=follow_game_camera?canopy_focus.xyz:forest_focus;
 vec3 eye=canopy_observer();
 if(follow_game_camera && distance(eye,forest_vertex)<1.85)return true;
 vec3 ray=eye-focus;float length_=max(dot(ray,ray),.01);
 float u=dot(forest_vertex-focus,ray)/length_;
 if(u<.02 || u>1.08)return false;
 return distance(forest_vertex,focus+ray*clamp(u,0.,1.))<mix(.90,1.5,clamp(u,0.,1.));
}
