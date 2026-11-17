shader_type spatial;
render_mode cull_back;
uniform sampler2D ripple_normal:hint_normal,repeat_enable,filter_linear_mipmap_anisotropic;
uniform bool jet=false;
uniform vec4 water_color : source_color=vec4(.25,.66,.73,1);
varying vec3 p;
varying vec3 water_world;
varying vec3 water_right;
varying vec3 water_back;
void vertex(){p=VERTEX;water_world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;water_right=normalize((MODELVIEW_MATRIX*vec4(1.,0.,0.,0.)).xyz);water_back=normalize((MODELVIEW_MATRIX*vec4(0.,0.,1.,0.)).xyz);}
void fragment(){
 float rings=sin(length(p.xz)*18.0-TIME*2.7+sin(p.x*3.+p.z*2.1)*.7)+sin(p.x*9.0+p.z*7.0+TIME*.8)*.25;
 float flow=sin(UV.y*62.0-TIME*8.0)+sin(UV.y*113.0-TIME*12.0)*.3;
 float glint=smoothstep(.58,1.0,jet?flow:rings);
 float edge=smoothstep(2.25,2.65,length(p.xz));
 ALBEDO=mix(water_color.rgb*.74,vec3(.57,.83,.80),jet?glint*.65:glint*.14+edge*.20);
 EMISSION=ALBEDO*.025;ROUGHNESS=.24;SPECULAR=.45;
 if(!jet){
  vec2 a=texture(ripple_normal,water_world.xz*.24+TIME*vec2(.014,.010)).rg*2.-1.;
  vec2 b=texture(ripple_normal,water_world.xz*.57-TIME*vec2(.01,.015)).rg*2.-1.;
  NORMAL=normalize(NORMAL+water_right*(a.x+b.x*.5)*.22+water_back*(a.y+b.y*.5)*.22);
 }
}
