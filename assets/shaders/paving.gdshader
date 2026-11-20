shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 stone_color : source_color = vec4(0.49,0.56,0.53,1.0);
uniform sampler2D paving_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float texture_scale=.27;
uniform bool coastal_stone=false;
uniform vec2 plaza_center=vec2(0.0);
varying vec3 world_pos;
float band(float radius, float center, float width, float aa){
	return 1.0-smoothstep(width-aa,width+aa,abs(radius-center));
}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 sample_color=texture(paving_texture,world_pos.xz*texture_scale).rgb;
 vec3 variation=clamp(sample_color/vec3(.2825,.2961,.2988),vec3(.45),vec3(1.50));
 ALBEDO=stone_color.rgb*mix(vec3(1.0),variation,.85);
 if(coastal_stone){
  vec2 p=world_pos.xz-plaza_center;
  float radius=length(p);
  // Salt-weathered limestone and an eight-point mariner's compass around the fountain.
  vec3 limestone=ALBEDO;
  if(radius<9.8){
   float aa=clamp(fwidth(radius),.008,.065);
   float rings=max(band(radius,8.82,.14,aa),band(radius,7.98,.045,aa));
   rings=max(rings,max(band(radius,4.88,.15,aa),band(radius,5.19,.044,aa)));
   float theta=atan(p.y,p.x);
   float arc=fract(theta/TAU*8.+.5)-.5;
   float tip=mix(5.85,7.32,step(.5,fract(theta/TAU*4.+.25)));
   float width=clamp((tip-radius)/(tip-3.35),0.,1.)*.39;
   float ray=(1.-smoothstep(width-.012,width+.012,abs(arc)))*smoothstep(3.26,3.36,radius)*(1.-smoothstep(tip-.04,tip,radius));
   vec3 slate=mix(vec3(.077,.184,.177),vec3(.43,.32,.165),step(0.,arc));
   limestone=mix(limestone,slate*(.58+.56*variation),ray*.94);
   limestone=mix(limestone,vec3(.18,.29,.255)*variation,rings*.83);
  }
  ALBEDO=limestone;
 }
 ROUGHNESS=.96;
}
