@tool
extends Control
## Resize bubble_size or the Control rect; text wraps inside the paper panel.

@export var bubble_size := Vector2(320, 132):
	set(value):
		bubble_size = Vector2(maxf(value.x, 170.0), maxf(value.y, 84.0))
		if is_node_ready():
			size = bubble_size
			_layout_text()
			queue_redraw()
@export_range(0.15, 0.85, 0.01) var tail_position := 0.5:
	set(value):
		tail_position = value
		queue_redraw()
@export var speaker_name := "Amelia":
	set(value):
		speaker_name = value
		if is_node_ready():
			_layout_text()
@export_multiline var message := "We should look more closely.":
	set(value):
		message = value
		if is_node_ready():
			_layout_text()

@onready var speaker_label: Label = $Speaker
@onready var message_label: Label = $Message


func _ready() -> void:
	custom_minimum_size = Vector2(170, 84)
	size = bubble_size
	_layout_text()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if is_node_ready():
			_layout_text()
		queue_redraw()


func _layout_text() -> void:
	speaker_label.text = speaker_name
	speaker_label.visible = not speaker_name.is_empty()
	speaker_label.position = Vector2(18, 10)
	speaker_label.size = Vector2(size.x - 36, 26)
	message_label.text = message
	message_label.position = Vector2(18, 37 if speaker_label.visible else 17)
	message_label.size = Vector2(size.x - 36, size.y - message_label.position.y - 29)


func _draw() -> void:
	var body := Rect2(1, 1, size.x - 2, size.y - 19)
	var tail_x := clampf(size.x * tail_position, 26.0, size.x - 26.0)
	var tail_outline := PackedVector2Array([
		Vector2(tail_x - 15, body.end.y - 3),
		Vector2(tail_x, size.y - 2),
		Vector2(tail_x + 14, body.end.y - 3),
	])
	var tail_paper := PackedVector2Array([
		Vector2(tail_x - 10, body.end.y - 5),
		Vector2(tail_x, size.y - 8),
		Vector2(tail_x + 9, body.end.y - 5),
	])
	draw_colored_polygon(tail_outline, Color("b58845"))
	draw_colored_polygon(tail_paper, Color("fff0d5"))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("fff0d5")
	panel.border_color = Color("b58845")
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(10)
	draw_style_box(panel, body)
