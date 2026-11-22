shader_type spatial;
render_mode cull_back;
uniform sampler2D courts:repeat_disable,filter_linear_mipmap;
uniform sampler2D stone:source_color,repeat_enable,filter_linear_mipmap_anisotropic;
uniform sampler2D turf:source_color,repeat_enable,filter_linear_mipmap_anisotropic;
uniform sampler2D paving:source_color,repeat_enable,filter_linear_mipmap_anisotropic;
uniform sampler2D earth:source_color,repeat_enable,filter_linear_mipmap_anisotropic;
varying vec3 pos;
void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
float noise2(vec2 v){vec2 i=floor(v),f=fract(v);f=f*f*(3.-2.*f);vec4 a=fract(sin(vec4(dot(i,vec2(127.1,311.7)))+vec4(0.,127.1,311.7,438.8))*43758.54);return mix(mix(a.x,a.y,f.x),mix(a.z,a.w,f.x),f.y);}
float way(vec2 p,vec2 a,vec2 b,float r){vec2 ba=b-a;return length(p-a-ba*clamp(dot(p-a,ba)/dot(ba,ba),0.,1.))-r;}
void fragment(){
	vec2 p=pos.xz;
	float n=noise2(p*.076),fine=noise2(p*.72);
	float lane=p.y>30.?9.*sin((p.y-38.)*.041)*sin(clamp((p.y-30.)/167.,0.,1.)*3.14159):0.;
	float palace=1.-smoothstep(-83.,-78.,p.y);
	float avenue=abs(p.x-lane)-mix(7.0,9.,palace);
	float river=abs(p.y-9.*sin(p.x*.015));
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
	float road=min(aisles,side);
	// Tangled lanes between shops wear down to earth and river cobbles on both sides.
	float wards=(1.-smoothstep(22.,43.,abs(p.x-lane)))*smoothstep(24.,54.,p.y)*(1.-smoothstep(181.,199.,p.y));
	float laid=1.-smoothstep(-.2,.70,road+.35*(fine-.5));
	vec3 lawn=texture(turf,p/5.9).rgb*mix(vec3(.67,.70,.59),vec3(.89,.88,.73),n);
	vec3 dirt=texture(earth,p/6.4).rgb*vec3(.87,.80,.67);
	lawn=mix(lawn,mix(dirt,texture(stone,p/4.6).rgb*vec3(.63,.65,.60),.57),wards*.89);
	lawn=mix(lawn,dirt,(1.-smoothstep(.2,3.3,road))*.83);
	vec3 grain=texture(stone,p/vec2(5.7,5.3)).rgb;
	vec3 flag=texture(paving,p/vec2(4.4,5.0)).rgb;
	float gutter=1.-smoothstep(.10,.26,abs(avenue+.35));
	float lip=1.-smoothstep(.16,.29,abs(avenue-.08));
	vec3 warm=mix(flag*vec3(.94,.87,.73),grain*vec3(.98,.91,.79),.25+.39*palace);
	vec3 flagstone=mix(warm,grain*vec3(.83,.85,.73),smoothstep(-.85,2.2,avenue)*.65);
	float gutter_run=abs(p.x-lane);
	float border=1.-smoothstep(.027,.115,abs(gutter_run-3.74));
	float brick=1.-smoothstep(.05,.22,abs(gutter_run-4.12));
	vec3 runners=texture(paving,vec2(p.y,p.x-lane)*vec2(.62,.94)).rgb*vec3(.63,.66,.64);
	flagstone=mix(flagstone,runners,brick*wards);
	flagstone=mix(flagstone,vec3(.258,.252,.192),border*wards*.72);
	flagstone*=.85+.17*n;flagstone=mix(flagstone,vec3(.115,.118,.092),gutter*.64);
	flagstone=mix(flagstone,vec3(.39,.36,.275),lip*.41);
	float garden=1.-smoothstep(2.2,3.5,abs(length((p-vec2(120.,-40.))*vec2(.75,.98))-11.));
	vec3 gravel=mix(dirt,flag*.78,.48+.12*fine);
	// Rain-darkened joints and occasional sprigs catch the side light along the edge of the lane.
	float wear=noise2(p*.33+vec2(9.,37.));
	float seam=1.-smoothstep(.055,.18,dot(grain,vec3(.28,.58,.14)));
	vec3 leaves=vec3(.095,.14,.056);
	flagstone=mix(flagstone,leaves,.21*seam*smoothstep(.40,.86,wear));
	vec3 apron=mix(lawn,flagstone,laid);
	float palace_beds=(1.-smoothstep(.14,.85,abs(abs(p.x)-(20.+2.*sin(p.y*.075)))-2.85))*step(p.y,-91.);
	apron=mix(apron,texture(earth,p/4.8).rgb*.67,palace_beds*.72*(1.-laid));
	vec3 district=texture(courts,(p+256.)/512.).rgb;
	vec3 normal_=normalize(cross(dFdx(pos),dFdy(pos)));
	float level=smoothstep(.77,.95,abs(normal_.y));
	vec2 twist=vec2(.916*p.x+.401*p.y,-.401*p.x+.916*p.y);
	vec3 court_flags=texture(paving,twist/vec2(3.8,4.8)).rgb*vec3(.79,.80,.73);
	float stone_edge=smoothstep(.05,.34,district.r)*(1.-smoothstep(.55,.90,district.r));
	vec3 stone_yard=mix(court_flags,gravel*.91,stone_edge*.68);
	apron=mix(apron,mix(dirt*.75,grain*vec3(.85,.80,.71),.62+.15*n),level*district.g*(1.-laid)*.98);
	apron=mix(apron,stone_yard,level*district.r*(1.-laid*.90));
	apron*=mix(vec3(1.),vec3(.61,.67,.68),district.b);
	// Reuse the worn surface colours as shallow relief, measured in metres.
	// Screen derivatives respect the slope and the rotated stone aprons without another texture fetch.
	float stone_cover=max(laid,district.r*level);
	vec3 stone_relief=mix(flag,court_flags,district.r*(1.-laid));
	float h=dot(stone_relief,vec3(.28,.57,.15))*.058*stone_cover;
	vec3 dx=dFdx(VERTEX),dy=dFdy(VERTEX);
	vec3 t=cross(dy,NORMAL),b=cross(NORMAL,dx);
	float det=dot(dx,t);
	vec3 grad=(t*dFdx(h)+b*dFdy(h))*sign(det)/max(abs(det),.000001);
	float proximity=1.-smoothstep(15.,36.,length(VERTEX));
	NORMAL=normalize(NORMAL-clamp(grad,vec3(-.38),vec3(.38))*proximity);
	ALBEDO=mix(apron,gravel,garden*(1.-laid*.68));
	ROUGHNESS=mix(.96,mix(.75,.92,wear),stone_cover);
}
