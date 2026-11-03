shader_type spatial;
render_mode diffuse_burley;
varying vec2 p;
uniform bool world_aligned=false;
uniform vec2 room_half_size=vec2(6.0,5.0);
uniform vec4 wood_color:source_color=vec4(.72,.52,.30,1.0);
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
void vertex(){p=world_aligned?(MODEL_MATRIX*vec4(VERTEX,1.0)).xz:VERTEX.xz;}
void fragment(){
 vec2 uv=p;float row=floor(uv.y*2.6);uv.x+=mod(row,3.0)*.77;
 vec2 f=fract(uv*vec2(.45,2.6));float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));float aa=max(fwidth(edge),.0005);
 float seam=smoothstep(.006-aa,.015+aa,edge);
 float streak=sin(uv.x*29.0+uv.y*143.0+sin(uv.x*3.0)*2.0)*.012;
 vec3 color=wood_color.rgb*(.94+hash(vec2(floor(uv.x*.45),row))*.12+streak);
 color=mix(wood_color.rgb*.67,color,seam);
 float wall_distance=min(room_half_size.x-abs(p.x),room_half_size.y-abs(p.y));
 if(!world_aligned)color*=1.0-.14*exp(-max(wall_distance,0.0)*4.0);
 ALBEDO=color;ROUGHNESS=.88;SPECULAR=.23;
}
