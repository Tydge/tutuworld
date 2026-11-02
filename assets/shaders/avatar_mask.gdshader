shader_type canvas_item;
void fragment(){vec4 c=texture(TEXTURE,UV);float a=1.0-smoothstep(.475,.495,length(UV-.5));COLOR=vec4(c.rgb,c.a*a);}
