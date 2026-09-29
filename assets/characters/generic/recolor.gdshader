shader_type canvas_item;

uniform sampler2D recolor_mask : filter_nearest, repeat_disable;
uniform bool recolor_skin = false;
uniform bool recolor_garment = false;
uniform vec4 skin_tone : source_color = vec4(0.82, 0.58, 0.42, 1.0);
uniform vec4 garment_color : source_color = vec4(0.32, 0.56, 0.65, 1.0);
uniform float skin_base_luma = 0.55;
uniform float garment_base_luma = 0.30;
uniform bool plant_feet = false;
uniform float foot_row = 35.0;
uniform vec2 frame_origin = vec2(0.0);
uniform vec2 plant_shift = vec2(0.0);

#include "res://assets/ui/mission_1/entity_outline.gdshaderinc"
void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE - frame_origin;
	vec2 source_uv = UV;
	if (plant_feet && pixel.y >= foot_row) source_uv += plant_shift * TEXTURE_PIXEL_SIZE;
	vec4 original = texture(TEXTURE, source_uv);
	vec2 mask = texture(recolor_mask, source_uv).rg;
	float luma = dot(original.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 result = original.rgb;
	if (recolor_skin && mask.r > 0.5) {
		result = clamp(skin_tone.rgb * luma / skin_base_luma, vec3(0.0), vec3(1.0));
	} else if (recolor_garment && mask.g > 0.5) {
		result = clamp(garment_color.rgb * luma / garment_base_luma, vec3(0.0), vec3(1.0));
	}
	COLOR = vec4(result, original.a);
	#include "res://assets/ui/mission_1/outline_fragment.gdshaderinc"
}
