shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled,fog_disabled;

varying float opacity;

void vertex() {
	vec4 center = MODELVIEW_MATRIX * vec4(0., 0., 0., 1.);
	float depth = -center.z;
	float scale = length(MODEL_MATRIX[0].xyz);
	float width = clamp(14.0 * scale / max(depth, 1.0), 1.2, 2.1);
	opacity = smoothstep(1.0, 2.8, depth) * mix(.52, .24, smoothstep(5., 28., depth));
	vec4 clip = PROJECTION_MATRIX * center;
	// A short, soft fleck follows the wind, with a bounded size even close up.
	vec2 offset = (UV * 2. - 1.) * vec2(width, 1.45 * width);
	offset.x += .18 * offset.y;
	clip.xy += offset / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	float flake = 1. - smoothstep(.20, 1., length(UV * 2. - 1.));
	ALBEDO = vec3(.88, .93, 1.);
	ALPHA = flake * opacity;
}
