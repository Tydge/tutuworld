shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color=vec4(1.0);
uniform int pattern=0;
uniform bool vertex_tint=false;
uniform float opacity=1.0;
uniform float cut_base_height=-100.0;

uniform bool building_roof_cut=false;
uniform bool building_wall_cut=false;
uniform bool building_world_pattern=false;
uniform sampler2D building_cut_mask : filter_nearest, repeat_disable;
uniform vec4 building_grid_bounds=vec4(60.,-8.,38.,36.);
uniform vec3 building_view_position=vec3(0.);
uniform vec2 building_wall_normal=vec2(0.,1.);
uniform float roughness_value=.9;
uniform sampler2D plaster_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float plaster_strength=0.;
varying vec3 p;
varying vec3 local_pos;
varying vec3 local_normal;
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float bayer(vec2 v){vec2 q=mod(floor(v),4.0);return mod(mod(q.x,2.0)*2.0+mod(q.y,2.0)*3.0,4.0)*.25+mod(floor(q.x*.5)*2.0+floor(q.y*.5)*3.0,4.0)*.0625;}
vec3 display_color(vec3 c){return mix(1.055*pow(max(c,vec3(0.0)),vec3(1.0/2.4))-.055,c*12.92,lessThan(c,vec3(.0031308)));}
float building_hidden(vec2 position){
 vec2 uv=(position-building_grid_bounds.xy)/building_grid_bounds.zw;
 if(any(lessThan(uv,vec2(0.)))||any(greaterThanEqual(uv,vec2(1.))))return 0.;
 return texture(building_cut_mask,uv).r;
}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;local_pos=building_world_pattern?p:VERTEX;local_normal=building_world_pattern?(MODEL_NORMAL_MATRIX*NORMAL):NORMAL;}
void fragment(){
 if(building_roof_cut && building_hidden(p.xz)>.5)discard;
 if(building_wall_cut && p.y>=cut_base_height){
  float side=dot(building_view_position.xz-p.xz,building_wall_normal);
  if((side>0. && building_hidden(p.xz-building_wall_normal*.28)>.5)||(side<=0. && building_hidden(p.xz+building_wall_normal*.28)>.5))discard;
 }
 float visibility=(p.y<cut_base_height)?1.0:opacity;
 if(visibility<.001 || (visibility<.999 && bayer(FRAGCOORD.xy)>=visibility)) discard;
 vec3 vertex_color=OUTPUT_IS_SRGB?display_color(COLOR.rgb):COLOR.rgb;
 vec3 base=tint.rgb*(vertex_tint?vertex_color:vec3(1.0));
 vec3 color=base;
 float grain=(hash(floor(p.xz*110.0))-.5)*.014;
 if(pattern==1){
  vec2 uv=local_pos.xz;float row=floor(uv.y*3.2);uv.x+=mod(row,2.0)*1.05;
  vec2 f=fract(uv*vec2(.48,3.2));float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
  float aa=max(fwidth(edge),.001);float seam=smoothstep(.006-aa,.014+aa,edge);
  float streak=sin(uv.x*24.0+sin(uv.x*2.0+row)*2.8+uv.y*135.0)*.012;
  color*=.94+hash(vec2(floor(uv.x*.48),row))*.11+streak+grain;
  color=mix(base*.72,color,seam);
 }else if(pattern==2){
  vec2 uv=vec2(abs(local_pos.x)*2.2,local_pos.z*1.6);uv.y+=mod(floor(uv.x),2.0)*.5;
  vec2 f=fract(uv);float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
  float aa=max(fwidth(edge),.002);float seam=smoothstep(.015-aa,.04+aa,edge);
  color*=.94+hash(floor(uv))*.10+sin(f.y*3.14159)*.035;
  color=mix(base*.69,color,seam);
 }else if(pattern==3){
  vec2 uv=(abs(local_normal.z)>.6?local_pos.xy:local_pos.zy)*vec2(2.0,1.3);
  float row=floor(uv.y);uv.x+=mod(row,2.0)*.5;vec2 f=fract(uv);
  float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
  color*=mix(.74,.97+hash(floor(uv))*.08,smoothstep(.025,.06,edge));
 }else if(pattern==4){
  vec2 uv=(abs(local_normal.y)>.6?local_pos.xz:(abs(local_normal.z)>.6?local_pos.xy:local_pos.zy))*2.4;
  uv=mat2(vec2(.7071,.7071),vec2(-.7071,.7071))*uv;
  vec2 cell=floor(uv);vec2 f=fract(uv);float d=mod(cell.x-cell.y,8.);bool horizontal=d<4.;
  vec2 board=horizontal?vec2(d+f.x,f.y):vec2(f.x,7.-d+f.y);
  vec2 size=horizontal?vec2(4.,1.):vec2(1.,4.);
  vec2 start=horizontal?vec2(cell.x-d,cell.y):vec2(cell.x,cell.y-(7.-d));
  float edge=min(min(board.x,size.x-board.x),min(board.y,size.y-board.y));
  float seam=smoothstep(.008,.023+fwidth(edge),edge);float along=horizontal?uv.x:uv.y;float across=horizontal?uv.y:uv.x;
  float streak=sin(along*35.+sin(along*2.7+across)*2.+across*180.)*.022;
  color=mix(base*.64,base*(.91+hash(start)*.14+streak),seam);
 }else if(pattern==5){
  vec2 uv=(abs(local_normal.y)>.6?local_pos.xz:(abs(local_normal.z)>.6?local_pos.xy:local_pos.zy))*13.;
  vec2 cell=floor(uv);vec2 f=fract(uv)-.5;float h=hash(cell);
  vec2 center=vec2(hash(cell+2.),hash(cell+8.))*.5-.25;
  float shape=length((f-center)*vec2(1.,1.4));float chip=1.-smoothstep(.10,.15+fwidth(shape),shape);
  vec3 fleck=mix(base*.61,mix(base,vec3(.93,.83,.67),.45),step(.5,h));
  color=mix(base*(.99+grain),fleck,chip*step(.30,h));
 }else if(pattern==6){
  vec2 uv=(abs(local_normal.y)>.6?local_pos.xz:(abs(local_normal.z)>.6?local_pos.xy:local_pos.zy))*1.5;
  uv.x+=mod(floor(uv.y),2.)*.5;vec2 f=fract(uv)-.5;
  float stem=1.-smoothstep(.010,.022+fwidth(f.x),abs(f.x-.08*sin(f.y*5.)));
  float leaf=0.;
  for(int i=0;i<3;i++){
   vec2 q=f-vec2(i==1?-.12:.12,-.23+float(i)*.21);q.x+=(i==1?-1.:1.)*q.y*.7;
   leaf=max(leaf,1.-smoothstep(.75,1.+fwidth(q.x)*12.,length(q/vec2(.12,.065))));
  }
  vec2 bell=f-vec2(.01,.34);float bloom=1.-smoothstep(.8,1.,length(bell/vec2(.07,.075)));
  vec3 ink=mix(base*.62,vec3(.39,.54,.40),.40);
  color=mix(base*(1.+grain),ink,max(leaf*.7,stem*step(-.37,f.y)*step(f.y,.34))*.43);color=mix(color,mix(base,vec3(1.),.70),bloom);
 }else if(pattern==7){
  // Half-metre, antialiased ceramic tiles with a small sage quatrefoil.
  vec2 uv=(abs(local_normal.y)>.6?local_pos.xz:(abs(local_normal.z)>.6?local_pos.xy:local_pos.zy))*2.;
  vec2 cell=floor(uv);vec2 f=fract(uv)-.5;vec2 q=abs(f);
  float edge=min(.5-q.x,.5-q.y);float aa=max(fwidth(edge),.001);
  float seam=smoothstep(.008-aa,.019+aa,edge);
  vec3 sage=mix(base*.46,vec3(.16,.27,.19),.50);
  color=base*(.965+hash(cell)*.045);
  float petal=min(length((q-vec2(.14,0.))/vec2(.15,.070)),length((q-vec2(0.,.14))/vec2(.070,.15)));
  float motif=(1.-smoothstep(.89,1.04+fwidth(petal),petal))*step(.5,mod(cell.x+cell.y,2.));
  float line=1.-smoothstep(.006,.014+aa,abs(max(q.x,q.y)-.435));
  color=mix(color,sage,motif*.77+line*.30);
  color=mix(base*.76,color,seam);
 }else if(pattern==8){
  // Cream glazed subway tile, sage lower courses and an inset border.
  vec2 wall=abs(local_normal.y)>.6?local_pos.xz:(abs(local_normal.z)>.6?local_pos.xy:local_pos.zy);
  vec2 uv=wall*vec2(2.5,5.);uv.x+=mod(floor(uv.y),2.)*.5;
  vec2 f=fract(uv);float edge=min(min(f.x,1.-f.x),min(f.y,1.-f.y));float aa=max(fwidth(edge),.002);
  float seam=smoothstep(.009-aa,.024+aa,edge);
  float course=mod(p.y-.18,4.7);vec3 sage=mix(base*.60,vec3(.22,.34,.25),.48);
  vec3 glaze=mix(base,sage,1.-smoothstep(1.03,1.06,course));
  float border=1.-smoothstep(.025,.045+fwidth(course),abs(course-1.10));
  glaze=mix(glaze,sage,border*.80);
  glaze*=.97+hash(floor(uv))*.045+sin(f.x*3.14159)*sin(f.y*3.14159)*.025;
  color=mix(base*.73,glaze,seam);
 }else{color*=1.0+grain*.65;}
 if(plaster_strength>.001 && pattern==0){
  vec2 wall_uv=(abs(local_normal.z)>.6?p.xy:p.zy)*.65;
  float plaster=dot(texture(plaster_texture,wall_uv).rgb,vec3(.333333));
  color*=mix(1.,clamp(plaster/.72,.82,1.13),plaster_strength);
 }
 ALBEDO=color;ROUGHNESS=pattern==8?.34:(pattern==7?.58:roughness_value);SPECULAR=pattern==8?.36:.22;
}
