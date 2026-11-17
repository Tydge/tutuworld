uniform vec3 forest_focus=vec3(0.);
uniform vec3 forest_view=vec3(0.);
uniform bool forest_cut_enabled=false;
varying vec3 forest_vertex;
varying flat float forest_camera_pass;
// Resolve only the small viewing corridor. Shadow and reflection passes stay whole.
bool forest_obscures(){
 if(!forest_cut_enabled || forest_camera_pass<.5)return false;
 vec3 ray=forest_view-forest_focus;float length_=max(dot(ray,ray),.01);
 float u=dot(forest_vertex-forest_focus,ray)/length_;
 if(u<.02 || u>1.08)return false;
 return distance(forest_vertex,forest_focus+ray*clamp(u,0.,1.))<mix(.90,1.5,clamp(u,0.,1.));
}
