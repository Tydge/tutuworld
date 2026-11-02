shader_type spatial;
render_mode diffuse_burley, specular_disabled, shadows_disabled;
uniform vec4 rock_color:source_color=vec4(.40,.48,.42,1.);
uniform vec4 moss_color:source_color=vec4(.36,.49,.36,1.);
uniform bool shape_wobble=true;
varying vec3 p;
varying vec3 n;
void vertex(){
 if(shape_wobble) VERTEX*=1.+sin(VERTEX.x*7.+VERTEX.z*4.)*.045+sin(VERTEX.y*8.-VERTEX.x*2.)*.035;
 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;n=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment(){
 float detail=sin(p.x*1.6+sin(p.z*1.2)*2.)*sin(p.y*2.2)*.035;
 ALBEDO=mix(rock_color.rgb,moss_color.rgb,smoothstep(.2,.8,n.y))*(1.+detail);ROUGHNESS=1.;
}
