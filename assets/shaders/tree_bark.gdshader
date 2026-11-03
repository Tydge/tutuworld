shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 bark_color:source_color=vec4(.60,.39,.22,1.);
uniform sampler2D bark_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float opacity=1.;
varying vec3 p;
float bayer(vec2 pixel){vec2 q=mod(floor(pixel),4.);return mod(mod(q.x,2.)*2.+mod(q.y,2.)*3.,4.)*.25+mod(floor(q.x*.5)*2.+floor(q.y*.5)*3.,4.)*.0625;}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 if(opacity<.001 || (opacity<.999 && bayer(FRAGCOORD.xy)>=opacity))discard;
 vec3 grain=texture(bark_texture,vec2(UV.x,p.y*.36)).rgb;
 float detail=dot(grain,vec3(.299,.587,.114));
 float shade=mix(.72,1.23,smoothstep(.12,.48,detail));
 ALBEDO=bark_color.rgb*mix(1.,shade,.72);ROUGHNESS=.96;
}
