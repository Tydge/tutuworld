shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform sampler2D branches : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float opacity = 1.0;
uniform bool camera_occlusion = true;
uniform float cut_base_height = -100.0;
varying float world_y;
varying flat float player_view;
varying vec3 leaf_normal;

void vertex() {
	player_view = (PROJECTION_MATRIX[3][3] < 0.5 && distance(INV_VIEW_MATRIX[3].xyz, MAIN_CAM_INV_VIEW_MATRIX[3].xyz) < 0.01 && dot(INV_VIEW_MATRIX[2].xyz, MAIN_CAM_INV_VIEW_MATRIX[2].xyz) > 0.9999) ? 1.0 : 0.0;
	leaf_normal = MODELVIEW_NORMAL_MATRIX * NORMAL;
	world_y = (MODEL_MATRIX * vec4(VERTEX,1.0)).y;
}

void fragment() {
	vec4 leaf=texture(branches,UV);
	if(leaf.a<.34){discard;}
	vec3 botanical=leaf.rgb;
	if(leaf.g>leaf.r*1.02 && leaf.g>leaf.b*1.18){
		float value=dot(leaf.rgb,vec3(.25,.60,.15));
		botanical=mix(leaf.rgb,mix(vec3(.045,.175,.036),vec3(.58,.85,.20),clamp(value*1.7,0.,1.)),.45);
	}
	vec3 pigment=COLOR.rgb*botanical;
	if (world_y >= cut_base_height && opacity < 0.999 && (player_view > 0.5 || !camera_occlusion)) {
		float dither = fract(52.9829189 * fract(dot(floor(FRAGCOORD.xy), vec2(0.06711056, 0.00583715))));
		if (opacity <= dither) { discard; }
	}
	NORMAL = normalize(leaf_normal);
	ALBEDO = pigment;
	BACKLIGHT = pigment * 0.30;
	ROUGHNESS = 0.92;
}
