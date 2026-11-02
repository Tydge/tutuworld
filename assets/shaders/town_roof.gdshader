shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 tile_color:source_color=vec4(.4,.6,.55,1.0);
varying vec3 p;
float hash(vec2 v){return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453);}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 uv=p.xz*vec2(2.6,1.7);uv.y+=mod(floor(uv.x),2.0)*.5;
 vec2 f=fract(uv);float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
 float aa=max(fwidth(edge),.002);float seam=smoothstep(.012-aa,.035+aa,edge);
 vec3 tile=tile_color.rgb*(.94+hash(floor(uv))*.12+sin(f.x*PI)*.035);
 ALBEDO=mix(tile_color.rgb*.72,tile,seam);
 ROUGHNESS=.9;
}
