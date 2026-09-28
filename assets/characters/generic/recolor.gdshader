shader_type canvas_item;

uniform sampler2D recolor_mask : filter_nearest, repeat_disable;
uniform bool recolor_skin = false;
uniform bool recolor_garment = false;
uniform vec4 skin_tone : source_color = vec4(0.82, 0.58, 0.42, 1.0);
uniform vec4 garment_color : source_color = vec4(0.32, 0.56, 0.65, 1.0);
uniform float skin_base_luma = 0.55;
uniform float garment_base_luma = 0.30;

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	vec2 mask = texture(recolor_mask, UV).rg;
	float luma = dot(original.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 result = original.rgb;
	if (recolor_skin && mask.r > 0.5) {
		result = clamp(skin_tone.rgb * luma / skin_base_luma, vec3(0.0), vec3(1.0));
	} else if (recolor_garment && mask.g > 0.5) {
		result = clamp(garment_color.rgb * luma / garment_base_luma, vec3(0.0), vec3(1.0));
	}
	COLOR = vec4(result, original.a);
}
