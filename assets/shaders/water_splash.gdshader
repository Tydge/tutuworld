shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never;
uniform float clock=0.0;
uniform float daylight=1.0;
void fragment(){vec2 p=UV-.5;float r=length(p);float t=fract(clock*2.7);float ring=(1.0-smoothstep(.010,.030,abs(r-(.07+t*.34))))*(1.0-t);float spot=max(0.0,1.0-r*2.3)*.16;ALBEDO=vec3(.63,.88,.93)*mix(.4,1.0,daylight);ALPHA=ring*.60+spot;}
