shader_type spatial;
uniform vec4 silk:source_color=vec4(.83,.19,.068,1.);
uniform float warmth=.35;
void fragment(){
	float line=pow(.5+.5*cos(UV.x*TAU*12.),13.);
	float folds=.88+.12*sin(UV.x*TAU*12.);
	float seam=smoothstep(.014,.039,abs(UV.y-.5));
	ALBEDO=silk.rgb*folds*mix(.72,1.,seam)*mix(1.,.44,line);
	EMISSION=mix(silk.rgb,vec3(1.,.31,.05),.28)*warmth*(.27+.73*sin(PI*UV.y))*(1.-line*.63);
	ROUGHNESS=.86;
}
