shader_type spatial;
uniform vec4 ink : source_color;
uniform float roughness = .85;
uniform bool dot_eye = false;

void vertex() {
	float depth = max(0.0, -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z);
	float pixel = 2.0 * depth / (VIEWPORT_SIZE.y * abs(PROJECTION_MATRIX[1][1]));
	if (dot_eye) {
		// Each eye is a scaled unit sphere. Keep both dots legible as the face recedes.
		float radius = length(MODELVIEW_MATRIX[0].xyz);
		VERTEX *= clamp(1.2 * pixel / max(.001,radius), 1.0, 1.85);
	} else {
		// Keep the original embroidered stroke in close and telephoto views.
		VERTEX += NORMAL * clamp(0.55 * pixel - 0.009, 0.0, 0.036);
	}
}

void fragment() {
	ALBEDO = ink.rgb;
	ROUGHNESS = roughness;
}
