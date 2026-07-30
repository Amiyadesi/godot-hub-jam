shader_type canvas_item;

uniform vec2 size = vec2(1.0);
uniform vec2 center1 = vec2(0.5);
uniform vec2 center2 = vec2(0.5);
uniform float time1 : hint_range(0.0, 1.0) = 1.0;
uniform float time2 : hint_range(0.0, 1.0) = 0.0;
uniform float width1 : hint_range(0.0, 0.5) = 0.025;
uniform float width2 : hint_range(0.0, 0.5) = 0.08;
uniform float corner_radius : hint_range(0.0, 1.0) = 0.0;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(0.45, 0.95, 0.88, 1.0);

float rounded_box(vec2 point, vec2 bounds, float radius) {
	vec2 delta = abs(point) - bounds + radius;
	return min(max(delta.x, delta.y), 0.0) + length(max(delta, 0.0)) - radius;
}

void fragment() {
	float aspect_ratio = max(size.x, 1.0) / max(size.y, 1.0);
	vec2 point = UV - vec2(0.5);
	point.x *= aspect_ratio;

	float radius = clamp(corner_radius * 0.5, 0.0, 0.49);
	float distance_to_edge = rounded_box(point, vec2(aspect_ratio * 0.5, 0.5), radius);
	float inside = step(distance_to_edge, 0.0);
	float focus_amount = clamp(time2, 0.0, 1.0);

	float border = 1.0 - smoothstep(width1, width1 + 0.018, abs(distance_to_edge));
	float outside = step(0.0, distance_to_edge);
	float outer_halo = outside * (1.0 - smoothstep(0.0, width2, distance_to_edge));

	vec2 click_point = UV - center1;
	click_point.x *= aspect_ratio;
	float wave_radius = mix(0.04, max(aspect_ratio, 1.0) * 0.7, time1);
	float click_trace = 1.0 - smoothstep(0.0, 0.045, abs(length(click_point) - wave_radius));
	click_trace *= (1.0 - time1) * 0.16 * inside;

	float stable_outline = border * mix(0.18, 0.72, focus_amount);
	float quiet_fill = inside * focus_amount * 0.025;
	float halo = outer_halo * glow * 0.24;
	float alpha = clamp(stable_outline + quiet_fill + halo + click_trace, 0.0, 0.82);

	COLOR = vec4(color.rgb, color.a * alpha);
}
