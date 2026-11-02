shader_type spatial;
render_mode diffuse_burley, specular_disabled;
void fragment(){
 vec2 p=(UV-.5)*2.;float radius=length(p);
 float rings=sin(radius*65.+sin(atan(p.y,p.x)*4.)*.4);
 ALBEDO=mix(vec3(.54,.32,.15),vec3(.74,.51,.29),.62+rings*.14);
 ROUGHNESS=1.;
}
