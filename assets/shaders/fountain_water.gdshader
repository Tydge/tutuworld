shader_type spatial;
render_mode cull_disabled,diffuse_burley;
uniform sampler2D ripple_normal:hint_normal,repeat_enable,filter_linear_mipmap;
uniform bool jet=false;
uniform vec4 water_color:source_color=vec4(.15,.53,.60,1.);
uniform vec4 shallows:source_color=vec4(.46,.80,.80,1.);
uniform vec4 foam:source_color=vec4(.88,.97,1.,1.);
varying vec3 local;
varying vec3 right;
varying vec3 back;
varying float flight;

float pressure(float a){
	return 1.+.20*sin(TIME*1.57+.96*cos(2.*a))+.075*sin(TIME*.84+a);
}
void vertex(){
	local=VERTEX;
	right=normalize(MODELVIEW_NORMAL_MATRIX*vec3(1.,0.,0.));
	back=normalize(MODELVIEW_NORMAL_MATRIX*vec3(0.,0.,1.));
	flight=0.;
	if(jet && COLOR.r<.075){
		float t=UV.y;
		float pump=pressure(atan(local.z,local.x));
		VERTEX.y+=3.62*t*(1.-t)*(pump-1.);
		VERTEX.xz+=normalize(local.xz)*1.27*t*(sqrt(pump)-1.);
	} else if(jet){
		float seed=COLOR.b;
		float height=UV2.y;
		float t=fract(TIME/sqrt(8.*height/9.81)+COLOR.g);
		vec2 dir=vec2(cos(UV2.x),sin(UV2.x));
		float reach=COLOR.r<.35 ? 1.24+seed*.08 : (COLOR.r<.70 ? .27+.62*seed : .05+.28*seed);
		float pump=pressure(UV2.x);
		height*=pump;
		if(COLOR.r<.7)reach*=sqrt(pump);
		else VERTEX.xz+=dir*1.27*(sqrt(pump)-1.);
		vec2 wind=vec2(-dir.y,dir.x)*(seed-.5)*t*t*.23;
		vec2 travel=dir*reach*t+wind;
		VERTEX+=vec3(travel.x,4.*height*t*(1.-t)-.068*t,travel.y);
		vec3 velocity=vec3(dir.x*reach,4.*height*(1.-2.*t),dir.y*reach);
		vec2 vy=(MODELVIEW_MATRIX*vec4(velocity,0.)).xy;
		vec2 axis=vy/max(length(vy),.001);
		vec2 cross_=vec2(-axis.y,axis.x);
		float width=COLOR.a*.13*(.64+.58*t);
		float stretch=COLOR.r<.35 ? 2.25+.65*abs(1.-2.*t) : 1.14+abs(1.-2.*t);
		vec2 offset=(cross_*(UV.x-.5)+axis*(UV.y-.5)*stretch)*width*2.;
		vec3 local_right=normalize(vec3(MODELVIEW_MATRIX[0].x,MODELVIEW_MATRIX[1].x,MODELVIEW_MATRIX[2].x));
		vec3 local_up=normalize(vec3(MODELVIEW_MATRIX[0].y,MODELVIEW_MATRIX[1].y,MODELVIEW_MATRIX[2].y));
		VERTEX+=local_right*offset.x+local_up*offset.y;
		flight=t;
	}
}

void fragment(){
	if(jet && COLOR.r<.075){
		float t=UV.y;
		float crest=pow(1.-abs(dot(normalize(NORMAL),VIEW)),2.);
		float flow=sin(t*57.-TIME*12.+COLOR.g*8.);
		ALBEDO=mix(shallows.rgb,foam.rgb,.23+.44*crest+.14*flow);
		ALPHA=(.17+.33*crest+.09*flow)*(1.-smoothstep(.56,1.,t)*.65);
		ROUGHNESS=.16;
		SPECULAR=.62;
	} else if(jet){
		vec2 p=UV*2.-1.;
		float r=dot(p,p);
		if(r>1.)discard;
		float fringe=1.-smoothstep(.35,1.,r);
		float silver=exp(-13.*dot(p-vec2(-.28,.16),p-vec2(-.28,.16)));
		float mist=step(.35,COLOR.r);
		vec3 base=mix(shallows.rgb,foam.rgb,.32+.24*COLOR.b+.27*silver);
		ALBEDO=base;
		BACKLIGHT=base*.27;
		EMISSION=base*(.045+.095*silver);
		ROUGHNESS=.29;
		SPECULAR=.32;
		ALPHA=fringe*mix(.51,.32,mist)*(.55+.45*sin(PI*flight))*(.7+.3*COLOR.b);
	} else {
		vec2 p=local.xz;
		float r=length(p);
		float theta=atan(p.y,p.x)-.18;
		float a=mod(theta+PI/8.,TAU/8.)-PI/8.;
		float landing=.75+1.27*sqrt(pressure(theta+.18-a));
		float impact=length(vec2(r*cos(a)-landing,r*sin(a)));
		vec2 n=texture(ripple_normal,p*.71+TIME*vec2(.021,.017)).rg*2.-1.;
		n+=.4*(texture(ripple_normal,p.yx*.99-TIME*.018).rg*2.-1.);
		float wave=impact*22.-TIME*6.35;
		float rings=sin(wave)*exp(-2.8*impact);
		float ripple=smoothstep(.40,.97,cos(wave))*exp(-2.6*impact);
		NORMAL=normalize(NORMAL+right*(n.x*.16+rings*.063)+back*(n.y*.16-rings*.052));
		float sky=pow(1.-max(0.,dot(VIEW,NORMAL)),2.9);
		vec2 tile=p*5.2+n*.15;
		float variation=sin(dot(floor(tile),vec2(31.73,11.28)))*.025;
		vec2 edges=abs(fract(tile)-.5);
		float grout=smoothstep(.441,.493,max(edges.x,edges.y));
		float light=sin(tile.x*2.+sin(tile.y*2.+TIME*.63))+sin(tile.y*2.31-TIME*.77+n.y*.8);
		vec3 basin=mix(water_color.rgb,shallows.rgb,.15+.43*smoothstep(1.6,2.82,r)+.13*grout+variation);
		basin+=shallows.rgb*(.19*smoothstep(1.32,1.92,light)+.25*ripple);
		basin=mix(basin,foam.rgb,(.44+.22*rings)*exp(-13.*impact));
		ALBEDO=mix(basin,vec3(.55,.73,.83),.49*sky);
		ROUGHNESS=.19;
		SPECULAR=.69;
		ALPHA=.94;
	}
}
