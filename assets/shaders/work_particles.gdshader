shader_type spatial;
render_mode unshaded,blend_mix,cull_disabled,depth_draw_never;
uniform vec3 start;
uniform vec3 finish;
uniform float clock=0.0;
uniform int kind=0;
uniform float daylight=1.0;
varying float life;
varying float seed;
void vertex(){
 seed=INSTANCE_CUSTOM.y;float phase=INSTANCE_CUSTOM.x;
 float speed=kind==0?1.9:(kind==1?1.6:1.5);
 life=fract(clock*speed+phase);
 vec3 axis=normalize(finish-start+vec3(.0001));vec3 right=normalize(cross(axis,vec3(0.0,1.0,.001)));vec3 up=normalize(cross(right,axis));
 float a=phase*TAU*9.0+seed*5.0;float radius=(kind==1?.38:.13)*life*sqrt(seed+.05);
 vec3 center=mix(start,finish,life)+(right*cos(a)+up*sin(a))*radius;
 if(kind==0) center.y+=sin(life*PI)*.05;
 if(kind==2){center=finish+vec3(cos(a)*.42*life,sin(life*PI)*.32,sin(a)*.42*life);}
 float s=kind==0?(.014+seed*.012):(.075+life*.13);
 vec3 world=center+INV_VIEW_MATRIX[0].xyz*VERTEX.x*s+INV_VIEW_MATRIX[1].xyz*VERTEX.y*s*(kind==0?1.9:1.0);
 POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(world,1.0);
}
void fragment(){
 float r=length(UV-.5)*2.0;float soft=pow(max(0.0,1.0-r),kind==0?.5:1.7);
 vec3 color=kind==0?vec3(.32,.75,.95):(kind==1?vec3(.87,.96,.84):vec3(.77,.65,.46));
 ALBEDO=color*mix(.4,1.0,daylight);ALPHA=soft*(kind==0?.9:.23)*smoothstep(0.0,.12,life)*(1.0-smoothstep(.75,1.0,life));
}
