shader_type canvas_item;

uniform float portal : hint_range(0.0, 1.0) = 0.0;
uniform float frame_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 page = texture(TEXTURE, UV);
	// A single wide window cuts through both pages. The broad smoothsteps
	// feather its edge like a softly blurred photograph in the diary.
	float across = smoothstep(0.13, 0.18, UV.x) *
		(1.0 - smoothstep(0.85, 0.90, UV.x));
	float down = smoothstep(0.12, 0.18, UV.y) *
		(1.0 - smoothstep(0.80, 0.86, UV.y));
	float window = across * down;
	page.a *= (1.0 - portal * window) * frame_alpha;
	COLOR = page;
}
