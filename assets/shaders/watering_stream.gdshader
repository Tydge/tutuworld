shader_type spatial;
render_mode blend_mix,cull_disabled,depth_draw_never;
uniform vec3 start;
uniform vec3 finish;
uniform float radius=.024;
uniform float clock=0.0;
varying float along;
void vertex(){
 along=VERTEX.y+.5;float t=along;
 vec3 center=mix(start,finish,t)+vec3(0.0,sin(t*PI)*.10,0.0);
 vec3 axis=normalize(finish-start+vec3(0.0,cos(t*PI)*.314,0.0));
 vec3 right=normalize(cross(axis,vec3(0.0,1.0,.001)));vec3 up=cross(right,axis);
 float ripple=1.0+sin(t*51.0-clock*17.0)*.12;
 vec3 world=center+(right*VERTEX.x+up*VERTEX.z)*radius*ripple;
 VERTEX=(inverse(MODEL_MATRIX)*vec4(world,1.0)).xyz;
 NORMAL=normalize(mat3(transpose(MODEL_MATRIX))*(right*NORMAL.x+up*NORMAL.z));
}
void fragment(){float flow=smoothstep(.55,.95,sin(along*49.0-clock*16.0));ALBEDO=mix(vec3(.24,.60,.77),vec3(.82,.97,1.0),flow*.7);ROUGHNESS=.16;SPECULAR=.75;EMISSION=ALBEDO*.06;ALPHA=.80;}
