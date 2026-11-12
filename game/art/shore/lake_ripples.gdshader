shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.275, 0.493, 0.525, 1.0);
uniform vec4 ripple_color : source_color = vec4(0.570, 0.744, 0.721, 1.0);

varying vec2 lake_xz;
varying float top_face;

void vertex() {
	// Sample in metres so the pattern meets across separate pieces of water.
	lake_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	top_face = max(0.0, normalize(MODEL_NORMAL_MATRIX * NORMAL).y);
}

void fragment() {
	float phase = TIME * 0.52359878;
	float swell = sin(dot(lake_xz, vec2(1.53, 0.44)) + 0.46 * sin(lake_xz.y * 0.63) - phase);
	float cross_wave = sin(dot(lake_xz, vec2(-1.04, 3.21)) + 0.70 * swell + 2.0 * phase);
	// Break up the crests and soften them before they become subpixel.
	float detail = 1.0 - smoothstep(0.20, 1.10, length(fwidth(lake_xz)));
	float crest = smoothstep(0.58, 0.94, swell * 0.67 + cross_wave * 0.33);
	float highlight = 0.40 * crest * detail * clamp(top_face, 0.0, 1.0);
	ALBEDO = mix(water_color.rgb, ripple_color.rgb, highlight);
	ROUGHNESS = mix(0.56, 0.34, highlight * 2.0);
	SPECULAR = 0.36;
}
