shader_type spatial;
uniform vec2 hands = vec2(5.24,1.05);
uniform float night = 0.0;

vec3 turn(vec3 p, vec3 axis, float angle) {
	float c=cos(angle);
	return p*c-cross(axis,p)*sin(angle)+axis*dot(axis,p)*(1.0-c);
}
void vertex(){
	// Vertex alpha identifies the enamel dial and each hand in the single baked draw.
	if(COLOR.a>0.5){
		vec3 face=abs(VERTEX.x)>abs(VERTEX.z)?vec3(sign(VERTEX.x),0.,0.):vec3(0.,0.,sign(VERTEX.z));
		vec3 hub=vec3(0.,2.47,0.)+face*1.93;
		float angle=COLOR.a>0.85?hands.y:hands.x;
		VERTEX=hub+turn(VERTEX-hub,face,angle);
		NORMAL=turn(NORMAL,face,angle);
	}
}
void fragment(){
	vec3 paint=OUTPUT_IS_SRGB?mix(COLOR.rgb*12.92,1.055*pow(COLOR.rgb,vec3(1./2.4))-.055,greaterThan(COLOR.rgb,vec3(.00313))):COLOR.rgb;
	ALBEDO=paint;
	ROUGHNESS=.76;
	if(COLOR.a>.18 && COLOR.a<.48){EMISSION=vec3(1.,.66,.33)*night*.52;}
}
