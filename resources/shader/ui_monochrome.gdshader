shader_type canvas_item;

uniform float contrast : hint_range(0.5, 2.0) = 1.18;
uniform float brightness : hint_range(-0.5, 0.5) = -0.03;
uniform float levels : hint_range(2.0, 8.0) = 5.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float gray = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	gray = clamp((gray - 0.5) * contrast + 0.5 + brightness, 0.0, 1.0);
	gray = floor(gray * (levels - 1.0) + 0.5) / (levels - 1.0);
	COLOR = vec4(vec3(gray), source.a);
}
