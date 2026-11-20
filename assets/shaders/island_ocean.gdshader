shader_type spatial;
render_mode diffuse_burley,cull_back,depth_draw_never;
#include "res://assets/shaders/painted_water.gdshaderinc"
uniform bool valley_estuary=false;
uniform bool coastal_bay=false;
uniform float solar_day=1.0;
uniform vec3 sun_direction=vec3(0.5,0.7,0.5);
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
 if(coastal_bay){
  float far_mix=smoothstep(40.,260.,distance_);
  // Fine ripples resolve in the foreground, broad swell carries the distant glints.
  vec2 p=water_world.xz;
  vec2 swell=vec2(cos(p.x*.19+p.y*.067+TIME*.52),sin(p.y*.22-p.x*.059-TIME*.43));
  vec3 wave=normalize(vec3(n.x*(1.-.84*far_mix)+swell.x*.043,1.,n.z*(1.-.84*far_mix)+swell.y*.062));
  NORMAL=normalize((VIEW_MATRIX*vec4(wave,0.)).xyz);
  vec3 eye=normalize(CAMERA_POSITION_WORLD-water_world);
  float sky_reflect=pow(1.-max(dot(wave,eye),0.),3.);
  vec3 water=mix(sea_color.rgb,sea_color.rgb*.70,1.-exp(-thickness*.16));
  ALBEDO=mix(water,horizon_color.rgb,(.37+.22*far_mix)*sky_reflect)+vec3(.47,.53,.49)*foam*.31;
  float shine=max(dot(wave,normalize(eye+sun_direction)),0.);
  float sun_height=smoothstep(-.015,.17,sun_direction.y);
  EMISSION=vec3(1.,.91,.78)*solar_day*(pow(shine,190.)*.55+pow(shine,1450.)*1.5)*sun_height;
 }
 ROUGHNESS=mix(.17,.36,smoothstep(35.,180.,distance_));SPECULAR=.68;
 ALPHA=clamp(mix(.36,.96,1.-exp(-thickness*.29))+fresnel*.32+foam*.28,.25,.995);
}
