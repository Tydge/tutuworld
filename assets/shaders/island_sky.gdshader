shader_type sky;
uniform vec4 zenith_color : source_color = vec4(.20,.49,.83,1);
uniform vec4 horizon_color : source_color = vec4(.63,.82,.94,1);
uniform vec4 cloud_color : source_color = vec4(.98,.98,.94,1);
uniform float daylight = 1.0;
uniform float night_amount = 0.0;
uniform float star_focus = 1.0;
uniform float cloud_detail = 0.0;
uniform float drift = 0.0;
#include "res://assets/shaders/sky_sampling.gdshaderinc"
void sky(){
 vec3 d=normalize(EYEDIR);
 float altitude=max(d.y,0.0);
 vec3 color=mix(horizon_color.rgb,zenith_color.rgb,pow(altitude,.48));
 if(d.y>0.0 && !AT_CUBEMAP_PASS){
  // Several scales keep small stars crisp alongside a few larger, brighter ones.
  vec2 stars_uv=vec2(atan(d.z,d.x)/TAU+.5,asin(clamp(d.y,-1.0,1.0))/PI+.5);
  float stars=pow(starlight(stars_uv),star_focus)/sqrt(star_focus);
  color+=vec3(.78,.85,1.0)*stars*night_amount*smoothstep(.015,.14,d.y);
  vec3 moon_direction=normalize(vec3(-.42,.38,-.82));
  float moon_distance=length(d-moon_direction);
  float glow=exp(-moon_distance*24.0)*.045;
  float disc=1.0-smoothstep(.026,.029,moon_distance);
  float crater=noise(d.xz*430.0)*.13;
  color+=night_amount*(vec3(.32,.44,.70)*glow+vec3(.82,.88,.77)*disc*(.91+crater));
  // Wide, soft cloud islands drift slowly; the night sky keeps plenty of clear gaps.
  vec2 p=d.xz/(d.y+.23)*2.7+vec2(drift*.012,drift*.004);
  float n=noise(p)*.65+noise(p*2.05)*.24+noise(p*4.1)*.11;
  float base=n;
  if(cloud_detail>0.0){
   vec2 warp=vec2(noise(p*.8+1.2),noise(p*.8+14.3))-.5;
   n=mix(n,noise(p+warp*.64)*.49+noise(p*2.05+warp)*.29+noise(p*4.05+warp)*.15+noise(p*9.2+warp)*.07,cloud_detail);
  }
  float cloud=smoothstep(.59,.73,n)*smoothstep(.02,.12,d.y);
  color=mix(color,cloud_color.rgb*mix(vec3(.88+noise(p+3.1)*.12),mix(vec3(.63,.76,.86),vec3(1.,.98,.92),smoothstep(.50,.73,base+.09*noise(p*2.))),cloud_detail),cloud*mix(.92,.14,night_amount));
 }
 COLOR=color;
}
