shader_type spatial;
render_mode specular_disabled;
uniform vec4 tint : source_color=vec4(1.0);
uniform bool vertex_tint=false;
uniform float opacity=1.0;
float leaf_hash(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
// Broad overlapping leaves, with variation kept in the material rather than hundreds of loose meshes.
vec2 leaf_surface(vec2 uv){
 vec2 p=uv*vec2(27.0,17.0);
 float row=floor(p.y);p.x+=mod(row,2.0)*.5;
 vec2 cell=floor(p),q=fract(p)-.5;
 float seed=leaf_hash(cell);
 q+=vec2(leaf_hash(cell+3.1)-.5,leaf_hash(cell+7.4)-.5)*.34;
 float angle=(seed-.5)*1.25; q=mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)))*q;
 q.x+=q.y*(seed-.5)*.45;
 float width=.43*(1.0-.52*pow(abs(q.y)*1.7,1.35));
 float edge=abs(q.x)/max(width,.10);
 float seam=smoothstep(.82,1.08,edge);
 float ridge=(1.0-smoothstep(.0,.035,abs(q.x+q.y*.08)))*.022;
 float value=.94+seed*.11+(q.y+.5)*.07-seam*.10+ridge;
 return vec2(value,seed);
}
float screen_pattern(vec2 p){
 vec2 q=mod(floor(p),4.0);
 float a=mod(q.x,2.0)*2.0+mod(q.y,2.0)*3.0;
 float b=floor(q.x*.5)*2.0+floor(q.y*.5)*3.0;
 return mod(a,4.0)*.25+mod(b,4.0)*.0625;
}
vec3 linear_color(vec3 c){return mix(pow((c+vec3(.055))/1.055,vec3(2.4)),c/12.92,lessThan(c,vec3(.04045)));}
void fragment(){
 if(opacity<.001 || (opacity<.999 && screen_pattern(FRAGCOORD.xy)>opacity)) discard;
 vec3 foliage_color=OUTPUT_IS_SRGB?COLOR.rgb:linear_color(COLOR.rgb);
 vec2 leaf=leaf_surface(UV);
 vec3 foliage=foliage_color*leaf.x;
 foliage=mix(foliage,foliage*vec3(.85,1.0,1.07),leaf.y*.24);
 ALBEDO=tint.rgb*(vertex_tint?foliage:vec3(1.0));
 ROUGHNESS=.94;
}
