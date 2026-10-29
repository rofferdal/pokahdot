shader_type canvas_item;
render_mode unshaded;

uniform bool embossed = false;
uniform vec4 ink_color : source_color = vec4(0.05, 0.32, 0.13, 1.0);
varying vec4 item_tint;

void vertex() {
	item_tint = COLOR;
}

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	vec3 color = texture(TEXTURE, UV).rgb;
	float opacity = mask;
	if (embossed) {
		vec2 step_uv = TEXTURE_PIXEL_SIZE * 1.5;
		float relief = texture(TEXTURE, UV - step_uv).a - texture(TEXTURE, UV + step_uv).a;
		color = clamp(ink_color.rgb + vec3(relief * 0.14), vec3(0.0), vec3(1.0));
		opacity = clamp(mask * 0.24 + abs(relief) * 0.18, 0.0, 0.42) * ink_color.a;
	}
	COLOR = vec4(color, opacity) * item_tint;
}
