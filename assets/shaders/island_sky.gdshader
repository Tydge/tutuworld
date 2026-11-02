shader_type sky;
uniform vec4 zenith_color : source_color = vec4(.20,.49,.83,1);
uniform vec4 horizon_color : source_color = vec4(.63,.82,.94,1);
uniform vec4 cloud_color : source_color = vec4(.98,.98,.94,1);
uniform float daylight = 1.0;
uniform float night_amount = 0.0;
uniform float drift = 0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float star_layer(vec2 uv,float scale,float size,float threshold){
 vec2 p=uv*scale;vec2 cell=floor(p),f=fract(p);
 vec2 center=vec2(hash(cell+7.2),hash(cell+19.3))*.7+.15;
 float radius=length(f-center);
 return (1.0-smoothstep(size*.25,size,radius))*step(threshold,hash(cell+41.0));
}
void sky(){
 vec3 d=normalize(EYEDIR);
 float altitude=max(d.y,0.0);
 vec3 color=mix(horizon_color.rgb,zenith_color.rgb,pow(altitude,.48));
 if(d.y>0.0 && !AT_CUBEMAP_PASS){
  // Several scales keep small stars crisp alongside a few larger, brighter ones.
  vec2 stars_uv=vec2(atan(d.z,d.x)/TAU+.5,asin(d.y)/PI+.5);
  float stars=star_layer(stars_uv,420.0,.10,.975)*.6+star_layer(stars_uv,150.0,.10,.987);
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
  float cloud=smoothstep(.59,.73,n)*smoothstep(.02,.12,d.y);
  color=mix(color,cloud_color.rgb*(.88+noise(p+3.1)*.12),cloud*mix(.92,.14,night_amount));
 }
 COLOR=color;
}
