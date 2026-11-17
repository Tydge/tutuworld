// Two periodic normal samples + one existing depth-buffer read. No scene capture/SSR.
uniform sampler2D ripple_normal:hint_normal,repeat_enable,filter_linear_mipmap_anisotropic;
uniform sampler2D water_depth:hint_depth_texture,filter_nearest,repeat_disable;
uniform vec4 sea_color:source_color=vec4(.16,.44,.52,1.);
uniform vec4 horizon_color:source_color=vec4(.65,.82,.91,1.);
uniform float daylight=1.;
uniform vec2 flow=vec2(.018,.010);
uniform float ripple_strength=.28;
varying vec3 water_world;
varying vec3 water_base_normal;
vec3 ripple_flow(vec2 p,vec2 current){
 vec2 warp=vec2(sin(p.y*.137+p.x*.053),sin(p.x*.121-p.y*.047))*.075;
 vec2 a=texture(ripple_normal,p*.105+warp+TIME*current).rg*2.-1.;
 vec2 b=texture(ripple_normal,mat2(vec2(.8,.6),vec2(-.6,.8))*p*.26-warp*.7-TIME*current*.72).rg*2.-1.;
 return normalize(water_base_normal+vec3((a+b*.48)*ripple_strength,0.).xzy);
}
float water_thickness(vec2 screen,mat4 inv_projection,float surface_z){
 float depth=textureLod(water_depth,screen,0.).r;
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec3 ndc=vec3(screen,depth)*2.-1.;
 #else
 vec3 ndc=vec3(screen*2.-1.,depth);
 #endif
 vec4 position=inv_projection*vec4(ndc,1.);
 if(abs(position.w)<.000001)return 120.;
 return clamp(surface_z-position.z/position.w,0.,120.);
}
vec3 water_tint(float depth,float fresnel){
 vec3 deep=mix(sea_color.rgb,vec3(.018,.060,.064),.65);
 vec3 shallow=mix(sea_color.rgb,vec3(.040,.13,.09),.72);
 vec3 tint=mix(shallow,deep,1.-exp(-depth*.22));
 return mix(tint,horizon_color.rgb,fresnel*.16);
}
