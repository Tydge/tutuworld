shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
void vertex(){
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment(){
	float h=1.-UV.y;
	float centre=.5+.13*sin(h*7.-TIME*1.6)+.064*sin(h*14.-TIME*2.5);
	float width=.08+.21*h;
	float plume=exp(-pow((UV.x-centre)/width,2.));
	float curls=.58+.42*sin(h*13.-TIME*2.4+sin(UV.x*8.));
	ALBEDO=vec3(.95,.90,.77);
	ALPHA=plume*curls*smoothstep(.01,.17,h)*(1.-smoothstep(.40,1.,h))*.36;
}
