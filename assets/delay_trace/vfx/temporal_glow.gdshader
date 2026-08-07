shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_color : source_color = vec4(0.08, 0.02, 0.07, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.3, 0.82, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	float near_alpha = 0.0;
	near_alpha = max(near_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
	near_alpha = max(near_alpha, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a);
	near_alpha = max(near_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	near_alpha = max(near_alpha, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a);
	near_alpha = max(near_alpha, texture(TEXTURE, UV + pixel * 2.0).a * 0.55);
	near_alpha = max(near_alpha, texture(TEXTURE, UV - pixel * 2.0).a * 0.55);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float tone = smoothstep(0.36, 0.64, luminance);
	vec3 core = mix(shadow_color.rgb, light_color.rgb, tone);
	float halo = max(near_alpha - source.a, 0.0) * glow_strength;
	vec3 color = mix(light_color.rgb, core, source.a);
	COLOR = vec4(color, max(source.a * opacity, halo));
}
