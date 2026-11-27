shader_type sky;
render_mode use_half_res_pass;
uniform vec4 zenith_color : source_color = vec4(.12,.32,.57,1.);
uniform vec4 horizon_color : source_color = vec4(.93,.70,.59,1.);
uniform vec4 cloud_color : source_color = vec4(.95,.83,.74,1.);
uniform float daylight=1.;
uniform float night_amount=0.;
uniform float drift=0.;
uniform vec3 sun_direction=vec3(.6,.16,-.7);
uniform vec3 moon_direction=vec3(-.6,.75,.1);
uniform float solar_visibility=1.;
uniform sampler2D mountain_panorama : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
#include "res://assets/shaders/sky_sampling.gdshaderinc"
float fbm(vec2 p){return noise(p)*.52+noise(p*2.03)*.26+noise(p*4.11)*.14+noise(p*8.27)*.08;}
void sky(){
 vec3 d=normalize(EYEDIR);float h=max(0.,d.y);
 vec3 col=mix(horizon_color.rgb,zenith_color.rgb,pow(h,.46));
 float sun_dot=max(0.,dot(d,normalize(sun_direction)));
 col+=vec3(1.,.48,.18)*pow(sun_dot,14.)*.25*solar_visibility;
 col+=vec3(1.,.88,.63)*smoothstep(.99994,.99997,sun_dot)*2.8*solar_visibility;
 if(AT_HALF_RES_PASS || AT_CUBEMAP_PASS){
  vec2 p=d.xz/(h+.16)*2.+vec2(drift*.0017,drift*.0006);
  float base=fbm(p*vec2(.55,1.6));
  float wisps=fbm(p*vec2(.43,4.5)+base*.7);
  float clouds=smoothstep(.43,.68,base*.72+wisps*.28)*smoothstep(.015,.12,h);
  vec3 shadow=mix(zenith_color.rgb*.7,cloud_color.rgb,.35);
  vec3 cloud=mix(shadow,cloud_color.rgb,smoothstep(.49,.72,base)+pow(sun_dot,5.)*.3);
  col=mix(col,cloud,clouds*.79);
  ALPHA=1.;
 }else{col=HALF_RES_COLOR.rgb;}
 if(!AT_CUBEMAP_PASS && !AT_HALF_RES_PASS && night_amount>0.){
  vec2 uv=vec2(atan(d.z,d.x),asin(clamp(d.y,-1.,1.)));
  float star=starlight(d);
  col+=star*night_amount*smoothstep(.03,.3,h)*vec3(.7,.8,1.);
  float moon_dist=length(d-normalize(moon_direction));
  col+=vec3(.58,.69,.84)*(1.-smoothstep(.0040,.0048,moon_dist))*night_amount*.32;
  col+=vec3(.24,.36,.58)*exp(-moon_dist*65.)*night_amount*.018;
  float curtain=sin(uv.x*6.+sin(uv.x*11.+drift*.0008))*.065+.30;
  float aurora=exp(-abs(uv.y-curtain)*34.)*pow(.5+.5*sin(uv.x*83.+sin(uv.x*19.)*3.),3.);
  col+=mix(vec3(.12,.57,.44),vec3(.29,.18,.55),noise(d.xz*8.))*aurora*night_amount*.27;
 }
 // A photographic far-distance horizon complements real 3D foothills. It also
 // participates in radiance and the reflected view, with the same day/night tint.
 float az=atan(d.z,d.x)/TAU+.5;
 float angle=asin(clamp(d.y,-1.,1.));
 float opening=1.-smoothstep(.45,.84,d.z);
 float mountain_v=1.-(angle+.035)/.30;
 if(!AT_HALF_RES_PASS && mountain_v>=0. && mountain_v<=1.){
  vec4 mountain=texture(mountain_panorama,vec2(az*6.+.12,mountain_v));
  vec3 tint=mix(vec3(.10,.19,.34),vec3(.91,.97,1.),daylight);
  vec3 rock=mountain.rgb*tint;
  rock=mix(rock,horizon_color.rgb,.16+night_amount*.08+(1.-opening)*.42);
  col=mix(col,rock,smoothstep(.12,.90,mountain.a)*opening*(1.-smoothstep(.82,1.,mountain_v)));
 }
 COLOR=col;
}
