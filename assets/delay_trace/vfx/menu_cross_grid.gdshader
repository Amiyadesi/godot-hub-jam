shader_type canvas_item;
render_mode unshaded;

uniform vec4 background_color : source_color = vec4(0.018, 0.025, 0.028, 1.0);
uniform vec4 cross_color : source_color = vec4(0.82, 0.88, 0.88, 0.16);
uniform float grid_size : hint_range(16.0, 128.0) = 64.0;
uniform float cross_arm : hint_range(2.0, 16.0) = 6.0;
uniform float line_width : hint_range(0.5, 3.0) = 1.0;

void fragment() {
	vec2 pixel = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec2 cell = mod(pixel, grid_size) - vec2(grid_size * 0.5);
	float vertical = (1.0 - step(line_width, abs(cell.x))) * (1.0 - step(cross_arm, abs(cell.y)));
	float horizontal = (1.0 - step(line_width, abs(cell.y))) * (1.0 - step(cross_arm, abs(cell.x)));
	float cross = max(vertical, horizontal);
	COLOR = mix(background_color, vec4(cross_color.rgb, 1.0), cross * cross_color.a);
}
