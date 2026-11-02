shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_disabled;
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 v){vec2 i=floor(v),f=fract(v);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void fragment(){
 vec2 q=(UV-.5)*vec2(1.,1.8);float mask=1.-smoothstep(.30,.56,length(q));
 float foam=noise(UV*vec2(32.,9.)-vec2(.15,TIME*.9));
 float holes=smoothstep(.28,.65,foam);
 ALBEDO=vec3(.63,.79,.72);ALPHA=mask*holes*.65;ROUGHNESS=1.;
}
