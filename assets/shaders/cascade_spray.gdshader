shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_disabled;
varying float life;
void vertex(){
 life=fract(TIME/.72+INSTANCE_CUSTOM.x);
 VERTEX*=.7+INSTANCE_CUSTOM.z*.6;
 VERTEX+=vec3((INSTANCE_CUSTOM.y-.5)*life*.9,(.7+INSTANCE_CUSTOM.z*.5)*life-1.5*life*life,INSTANCE_CUSTOM.w*life*.45);
}
void fragment(){ALBEDO=vec3(.62,.80,.74);ROUGHNESS=.7;ALPHA=smoothstep(0.,.1,life)*(1.-smoothstep(.55,1.,life))*.6;}
