shader_type spatial;
render_mode unshaded, blend_mul, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float clock=0.;
varying vec4 mark;
void vertex(){mark=INSTANCE_CUSTOM;}
void fragment(){
 vec2 p=UV*2.-1.;
 float d=length(p);
 float age=clock-mark.x;float life=mark.y;
 float fade=(1.-smoothstep(life-5.,life,age))*step(0.,age)*step(.1,life);
 float bowl=1.-smoothstep(.22,.86,d);
 float rim=exp(-pow((d-.62)*9.,2.))*.055;
 float shade=(bowl*.20+rim)*(1.+p.y*.12)*fade;
 // Multiplication can only darken the underlying snow, including at night.
 // The white area outside the small circle is neutral, never a glowing decal.
 ALBEDO=vec3(1.-shade);ALPHA=1.;
}
