shader_type spatial;
render_mode diffuse_burley, specular_disabled, shadows_disabled;
uniform vec4 rock_color:source_color=vec4(.40,.48,.42,1.);
uniform vec4 moss_color:source_color=vec4(.36,.49,.36,1.);
uniform sampler2D rock_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D turf_texture:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform float texture_strength:hint_range(0.,1.)=.88;
uniform float rock_scale=.15;
uniform bool shape_wobble=true;
varying vec3 p;
varying vec3 n;
void vertex(){
 if(shape_wobble) VERTEX*=1.+sin(VERTEX.x*7.+VERTEX.z*4.)*.045+sin(VERTEX.y*8.-VERTEX.x*2.)*.035;
 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;n=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment(){
 vec3 normal_world=normalize(n);
 vec3 weights=pow(abs(normal_world),vec3(4.));weights/=max(dot(weights,vec3(1.)),.001);
 // World-space triplanar sampling avoids stretched UVs on the old round meshes.
 vec3 stone=texture(rock_texture,p.yz*rock_scale).rgb*weights.x
           +texture(rock_texture,p.xz*rock_scale).rgb*weights.y
           +texture(rock_texture,p.xy*rock_scale).rgb*weights.z;
 float detail=sin(p.x*1.6+sin(p.z*1.2)*2.)*sin(p.y*2.2)*.035;
 vec3 original=mix(rock_color.rgb,moss_color.rgb,smoothstep(.2,.8,n.y))*(1.+detail);
 float grass_detail=dot(texture(turf_texture,p.xz*.38).rgb,vec3(.333333));
 vec3 turf=moss_color.rgb*mix(1.,clamp(grass_detail/.18,.93,1.07),.30);
 float weathering=sin(p.x*.13+p.z*.08)*sin(p.y*.19-p.z*.12)*.045;
 float grass=smoothstep(.65+weathering,.94+weathering,normal_world.y);
 vec3 textured=mix(mix(rock_color.rgb,stone*vec3(.88,.95,.91),.78),turf,grass*.92);
 float distance_soften=mix(1.,.45,smoothstep(65.,140.,length(VERTEX)));
 ALBEDO=mix(original,textured,texture_strength*distance_soften);ROUGHNESS=1.;
}
