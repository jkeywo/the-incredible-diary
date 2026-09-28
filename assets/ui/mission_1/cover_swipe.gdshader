shader_type canvas_item;

uniform float open_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	// The right edge of the cover sweeps towards its spine with a slight curl.
	float edge = 1.05 - open_progress * 1.12 + 0.035 * sin(UV.y * 3.14159265);
	float visible_cover = 1.0 - smoothstep(edge - 0.035, edge + 0.012, UV.x);
	float curl_shadow = (1.0 - smoothstep(0.0, 0.065, abs(UV.x - edge))) * 0.32;
	ink.rgb *= 1.0 - curl_shadow;
	ink.a *= visible_cover;
	COLOR = ink;
}
