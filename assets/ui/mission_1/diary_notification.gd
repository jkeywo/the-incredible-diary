@tool
extends Control
## Names a casualty or new diary entry without adding an unwitnessed cause.

@export var message := "A new entry has appeared in the diary.":
	set(value):
		message = value
		if is_node_ready():
			$Message.text = value


func _ready() -> void:
	$Message.text = message


func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("102139")
	panel.border_color = Color("d0a25d")
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(10)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(18, 15, 31, 43), Color("c39247"))
	draw_rect(Rect2(23, 19, 22, 35), Color("f6e6bd"))
	draw_line(Vector2(33, 25), Vector2(33, 48), Color("b0884d"), 1.0)
