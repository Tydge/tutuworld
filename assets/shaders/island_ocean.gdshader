shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform vec4 sea_color : source_color = vec4(.12,.48,.70,1);
uniform vec4 horizon_color : source_color = vec4(.63,.82,.94,1);
uniform float daylight=1.0;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 float range_=length(VERTEX);
 float shore_radius=length(vec2(p.x,p.y/.88));
 float shallow=1.0-smoothstep(54.,72.,shore_radius);
 vec3 water=mix(sea_color.rgb,sea_color.rgb*vec3(.72,1.16,1.13),shallow*.42);
 float wave=sin(p.x*.72+p.y*.31+sin(p.y*.38-TIME*.18)*1.6+TIME*.28);
 float wave2=sin(p.y*1.65-p.x*.27+TIME*.42);
 float aa=max(fwidth(wave),.015);
 float glint=smoothstep(.92-aa,.99+aa,wave)*smoothstep(.38,.9,wave2);
 float swell=sin(p.x*.15+p.y*.10+TIME*.19)*.018;
 float foam=(1.0-smoothstep(.04,.28,abs(shore_radius-56.2-sin(TIME*.48)*.22)))*.26;
 water+=vec3(.12,.20,.22)*(glint*.22+foam+swell)*(.18+daylight*.82);
 ALBEDO=mix(water,horizon_color.rgb,smoothstep(95.,330.,range_));
}
