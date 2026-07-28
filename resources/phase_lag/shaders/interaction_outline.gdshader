shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float outline_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(0.36, 1.0, 0.84, 1.0);
uniform float outline_width : hint_range(1.0, 4.0) = 2.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 pixel = TEXTURE_PIXEL_SIZE * outline_width;
	float nearby_alpha = 0.0;
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + pixel).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - pixel).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);
	float outline_alpha = max(nearby_alpha - base.a, 0.0) * outline_strength;
	vec4 outlined = vec4(outline_color.rgb, outline_color.a * outline_alpha);
	COLOR = mix(outlined, base, base.a);
}
