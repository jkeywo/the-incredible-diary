shader_type canvas_item;
uniform bool plant_feet = false;
uniform float foot_row = 35.0;
uniform vec2 frame_origin = vec2(0.0);
uniform vec2 plant_shift = vec2(0.0);
#include "res://assets/ui/mission_1/entity_outline.gdshaderinc"
void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE - frame_origin;
	vec2 source_uv = UV;
	if (plant_feet && pixel.y >= foot_row) source_uv += plant_shift * TEXTURE_PIXEL_SIZE;
	COLOR = texture(TEXTURE, source_uv);
	#include "res://assets/ui/mission_1/outline_fragment.gdshaderinc"
}
