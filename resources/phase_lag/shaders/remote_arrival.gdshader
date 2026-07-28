shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform int event_kind = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float effect_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 source_tint : source_color = vec4(0.35, 0.95, 0.88, 1.0);
uniform bool low_flash_mode = false;
uniform bool sample_canvas_group = false;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

float pixel_noise(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 pixel = (sample_canvas_group ? SCREEN_PIXEL_SIZE : TEXTURE_PIXEL_SIZE) * 4.0;
	float settle = 1.0 - progress;
	vec2 ghost_offset = vec2(pixel.x * 7.0 * settle, 0.0);
	vec4 base = texture(TEXTURE, UV);
	vec4 shifted = texture(TEXTURE, UV + ghost_offset);
	if (sample_canvas_group) {
		base = textureLod(screen_texture, SCREEN_UV, 0.0);
		shifted = textureLod(screen_texture, SCREEN_UV + ghost_offset, 0.0);
	}
	base *= COLOR;
	shifted *= COLOR;
	float scan_speed = low_flash_mode ? 2.0 : 7.0;
	float scan = 0.5 + 0.5 * sin((UV.y * 96.0) - TIME * scan_speed);
	float stable_pulse = 0.72 + 0.18 * sin(TIME * 2.0);
	float pulse = low_flash_mode ? stable_pulse : step(0.38, scan);
	vec4 result = base;

	if (event_kind == 0) {
		float current = scan * pulse * effect_strength * (0.35 + 0.65 * progress);
		result.rgb += source_tint.rgb * current * base.a;
	} else if (event_kind == 1) {
		float ghost_mix = effect_strength * settle * 0.62;
		result = mix(base, shifted * source_tint, ghost_mix);
		result.rgb += source_tint.rgb * effect_strength * progress * 0.18 * base.a;
	} else {
		vec2 cell = floor(UV * vec2(24.0, 18.0));
		float debris = step(pixel_noise(cell), progress * 0.28);
		float peel = debris * effect_strength * (low_flash_mode ? 0.22 : 0.42);
		result.rgb = mix(base.rgb, source_tint.rgb, peel * base.a);
		result.a = base.a * (1.0 - peel * 0.28);
	}

	COLOR = result;
}
