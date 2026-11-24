float way(vec2 p,vec2 a,vec2 b,float r){vec2 ba=b-a;return length(p-a-ba*clamp(dot(p-a,ba)/dot(ba,ba),0.,1.))-r;}
// Shared by the terrain and offline planting. Distances are in world metres.
float jade_road(vec2 p, out float lane, out float palace, out float avenue, out float river, out float fan_width, out float gate_yard) {
	lane=p.y>30.?9.*sin((p.y-38.)*.041)*sin(clamp((p.y-30.)/167.,0.,1.)*3.14159):0.;
	palace=1.-smoothstep(-83.,-78.,p.y);
	avenue=abs(p.x-lane)-mix(7.0,9.,palace);
	river=abs(p.y-9.*sin(p.x*.015));
	float embankment=abs(river-17.5)-3.2;
	float bazaar=max(abs(p.x-lane)-14.2,abs(p.y-111.)-82.);
	float eastwing=max(abs(p.y+138.)-52.,abs(abs(p.x)-37.+2.1*sin(p.y*.05))-5.8);
	float court=max(abs(p.x)-min(54.,25.+max(0.,-p.y-112.)*.42),abs(p.y+161.)-28.);
	float side=min(way(p,vec2(-176,111),vec2(-77,86),3.7),way(p,vec2(-77,86),vec2(-7,75),3.3));
	side=min(side,way(p,vec2(8,69),vec2(171,78),3.8));side=min(side,way(p,vec2(19,127),vec2(174,145),3.1));
	float crossroad=max(abs(p.y+63.-4.*sin(p.x*.053))-3.1,abs(p.x)-120.);
	side=min(side,max(crossroad,32.-abs(p.x)));
	side=min(side,way(p,vec2(-108,-19),vec2(-109,-62),3.));side=min(side,way(p,vec2(108,-17),vec2(122,-54),2.4));
	side=min(side,way(p,vec2(-60,175),vec2(-40,41),2.7));side=min(side,way(p,vec2(45,171),vec2(52,22),2.8));
	side=min(side,max(abs(p.y+123.)-3.2,abs(p.x)-84.));
	float aisles=min(min(embankment,eastwing),min(court,min(bazaar,avenue)));
	// The processional approach flares from the bridge towards all three palace passages.
	float fan=1.-smoothstep(-81.,-46.,p.y);
	fan_width=mix(7.,18.3,fan);
	gate_yard=max(abs(p.x)-fan_width,abs(p.y+70.)-24.);
	aisles=min(aisles,gate_yard);
	return min(aisles,side);
}
float jade_gravel(vec2 p) {
	return 1.-smoothstep(2.2,3.5,abs(length((p-vec2(120.,-40.))*vec2(.75,.98))-11.));
}
