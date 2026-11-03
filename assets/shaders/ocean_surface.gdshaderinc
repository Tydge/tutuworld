// Shared ocean/outlet palette keeps the estuary continuous without screen reads.
vec3 ocean_albedo(vec2 coord,vec3 base,float day){
 float radius=length(vec2(coord.x,coord.y/.88));
 float shallows=1.-smoothstep(55.,80.,radius);
 vec3 water=mix(base*.88,base*vec3(.65,1.20,1.10),shallows*.66);
 float swell=sin(dot(coord,vec2(.33,.19))+TIME*.45)+sin(dot(coord,vec2(-.17,.49))-TIME*.34)*.55;
 float tiny=sin(dot(coord,vec2(1.13,.69))+swell*.7-TIME*.8);
 float aa=max(fwidth(tiny),.025);
 float glint=smoothstep(.91-aa,.995+aa,tiny)*smoothstep(.35,.88,sin(coord.y*.81-coord.x*.47+TIME*.52));
 float crests=smoothstep(.91,1.,sin(dot(coord,vec2(.57,.27))+swell*.24-TIME*.36));
 float detail_fade=1.-smoothstep(.20,.80,length(fwidth(coord)));
 return water+(vec3(.12,.23,.25)*glint*.28*detail_fade+vec3(.025,.06,.065)*crests*.4+swell*.007)*(.12+day*.88);
}
