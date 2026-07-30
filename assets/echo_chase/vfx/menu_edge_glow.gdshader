shader_type canvas_item;
render_mode blend_add;

uniform bool from_top = true;
uniform float fade_distance : hint_range(0.1, 1.0) = 0.82;

void fragment() {
	float distance_to_edge = from_top ? UV.y : 1.0 - UV.y;
	float edge_alpha = 1.0 - smoothstep(0.0, fade_distance, distance_to_edge);
	COLOR = vec4(COLOR.rgb, COLOR.a * edge_alpha);
}
