shader_type canvas_item;
render_mode unshaded;

uniform vec4 glow_color : source_color = vec4(1.0, 0.69, 0.2, 0.7);
uniform float intensity : hint_range(0.0, 1.0) = 0.55;
uniform float edge_width : hint_range(0.01, 0.2) = 0.065;

void fragment() {
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge_glow = smoothstep(edge_width, 0.0, edge_distance);
	COLOR = vec4(glow_color.rgb, glow_color.a * edge_glow * intensity);
}
