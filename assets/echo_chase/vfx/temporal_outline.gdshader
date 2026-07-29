shader_type canvas_item;
render_mode unshaded;

uniform vec4 temporal_color : source_color = vec4(1.0, 0.3, 0.8, 1.0);
uniform float outline_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float neighbor_alpha = 0.0;
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);
	neighbor_alpha = max(neighbor_alpha, texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a);
	float outline = max(neighbor_alpha - source.a, 0.0) * outline_alpha;
	float fill = source.a * fill_alpha;
	COLOR = vec4(temporal_color.rgb, max(outline, fill) * temporal_color.a);
}
