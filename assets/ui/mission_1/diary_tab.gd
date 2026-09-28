@tool
extends Control
## Reusable page tab; new_entry is the subtle actionable-knowledge cue.

@export var label_text := "PEOPLE":
	set(value):
		label_text = value
		queue_redraw()
@export var selected := false:
	set(value):
		selected = value
		queue_redraw()
@export var new_entry := false:
	set(value):
		new_entry = value
		queue_redraw()


func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("e4c994") if selected else Color("20324a")
	panel.border_color = Color("b88c4b")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(5)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	draw_string(ThemeDB.fallback_font, Vector2(12, size.y * 0.65), label_text,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 35, 16,
		Color("17243a") if selected else Color("f2dcad"))
	if new_entry:
		draw_circle(Vector2(size.x - 16, size.y * 0.5), 5, Color("f3bd68"))
