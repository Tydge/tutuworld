shader_type spatial;
uniform vec4 silk:source_color=vec4(.83,.19,.068,1.);
uniform sampler2D silk_weave:source_color,repeat_enable,filter_linear_mipmap;
uniform float warmth=.35;
void fragment(){
	float ribs=.5+.5*cos(UV.x*TAU*12.);
	float mask=1.-smoothstep(.024,.078,fwidth(UV.x));
	float line=pow(ribs,12.)*mask;
	float body=clamp(sin(PI*UV.y),0.,1.);
	float stitch=smoothstep(.010,.025,abs(UV.y-.49));
	float weave=dot(texture(silk_weave,vec2(UV.x*3.,UV.y*1.4)).rgb,vec3(.30,.56,.14));
	float w=clamp(weave*2.5,.0,1.);
	ALBEDO=silk.rgb*(.70+.20*ribs+.10*w)*mix(.78,1.,stitch)*(1.-.55*line);
	// Oiled paper is brightest around the wick and darkens where the silk wraps the frames.
	float ember=1.-smoothstep(.06,.50,abs(UV.y-.56));
	vec3 light=mix(vec3(.56,.070,.013),vec3(1.,.50,.115),ember*ember);
	float rim=smoothstep(.07,.21,UV.y)*(1.-smoothstep(.81,.94,UV.y));
	float band=1.-smoothstep(.008,.018,min(abs(UV.y-.22),abs(UV.y-.79)));
	EMISSION=light*warmth*(.18+.68*body*rim)*(.83+.17*w)*(1.-.65*line)*(1.-.37*band*mask);
	ROUGHNESS=.89;
}
