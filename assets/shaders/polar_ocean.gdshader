shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform vec4 sea_color:source_color=vec4(.05,.15,.23,1.);
uniform vec4 horizon_color:source_color=vec4(.3,.45,.6,1.);
uniform float daylight=1.;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float footprint=length(fwidth(wp.xz));
 float detail=1.-smoothstep(.18,1.8,footprint);
 float a=wp.x*.75+wp.z*.43+TIME*.15;
 float b=wp.z*1.04-wp.x*.36+TIME*.19;
 vec3 n=normalize(vec3(sin(a)*.022+sin(b)*.012,1.,cos(a)*.018+cos(b)*.012)*vec3(detail,1.,detail));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.)).xyz);
 float fresnel=pow(1.-clamp(dot(NORMAL,VIEW),0.,1.),4.);
 ALBEDO=mix(vec3(.005,.018,.032),sea_color.rgb*.27,daylight);
 ROUGHNESS=mix(.24,.43,smoothstep(45.,800.,length(VERTEX)));
 SPECULAR=.48;METALLIC=0.;
}
