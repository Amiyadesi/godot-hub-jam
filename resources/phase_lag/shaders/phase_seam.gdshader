shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 cold_tint : source_color = vec4(0.3, 0.95, 0.88, 1.0);
uniform vec4 warm_tint : source_color = vec4(1.0, 0.38, 0.16, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform bool full_screen = false;
uniform bool low_flash_mode = false;

void fragment() {
	float speed = low_flash_mode ? 1.5 : 4.0;
	float phase = TIME * speed;
	float cell = floor(UV.x * 180.0);
	float fracture = sin(cell * 1.73 + phase) * 0.12 + sin(cell * 0.37 - phase * 0.6) * 0.08;
	float pulse = low_flash_mode ? 0.68 + 0.12 * sin(TIME * 1.6) : 0.72 + 0.24 * sin(TIME * 5.0);
	vec3 tint = mix(cold_tint.rgb, warm_tint.rgb, 0.5 + fracture * 2.0);
	float alpha;
	if (full_screen) {
		float band = 0.5 + 0.5 * sin((UV.y * 96.0) + fracture * 18.0 + phase);
		alpha = intensity * (0.12 + band * (low_flash_mode ? 0.08 : 0.16)) * pulse;
	} else {
		float center = 0.5 + fracture;
		float core = 1.0 - smoothstep(0.08, 0.5, abs(UV.y - center));
		alpha = core * intensity * pulse;
	}
	COLOR = vec4(tint, alpha * COLOR.a);
}
