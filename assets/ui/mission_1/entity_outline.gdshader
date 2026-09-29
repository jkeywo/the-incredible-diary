shader_type canvas_item;
uniform bool plant_feet = false;
uniform float foot_row = 35.0;
uniform vec2 frame_origin = vec2(0.0);
uniform vec2 plant_shift = vec2(0.0);
#include "res://assets/ui/mission_1/entity_outline.gdshaderinc"
void fragment() {
 #include "res://assets/ui/mission_1/outline_fragment.gdshaderinc"
}
