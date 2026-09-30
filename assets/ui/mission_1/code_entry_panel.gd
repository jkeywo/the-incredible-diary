@tool
extends Control
const Messages = preload("res://foundation/message_text.gd")
const Text = preload("res://localisation/source_text.gd")
## Manual three-digit code art. The game clock must keep running while shown.

signal option_confirmed(option: String)

@export var entered_digits := PackedInt32Array():
	set(value):
		entered_digits = value.slice(0, 3)
		queue_redraw()
@export_range(0, 7, 1) var selected_option := 0:
	set(value):
		selected_option = value
		queue_redraw()
@export var feedback := "":
	set(value):
		feedback = value
		queue_redraw()


func select_from_vector(direction: Vector2) -> void:
	if direction.length_squared() < 0.16:
		return
	var angle := wrapf(direction.angle() + PI / 2.0, 0.0, TAU)
	selected_option = int(round(angle / TAU * 6.0)) % 6


func confirm_selected() -> void:
	if selected_option < 6:
		option_confirmed.emit(str(selected_option + 1))
	elif selected_option == 6:
		option_confirmed.emit("confirm")
	else:
		option_confirmed.emit("clear")


func _draw() -> void:
	var panel := preload("res://assets/ui/popup/nine_piece_style.gd").new()
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(26, 37),Messages.ui(Text.UI_STEAM_CONTROL), HORIZONTAL_ALIGNMENT_LEFT,
		-1, 24, Color("efcd8a"))
	for index in range(3):
		var box := Rect2(96 + 80 * index, 62, 64, 61)
		draw_rect(box, Color("fff0d5"))
		draw_rect(box, Color("bb9256"), false, 3.0)
		var digit := str(entered_digits[index]) if index < entered_digits.size() else "—"
		draw_string(font, box.position + Vector2(13, 44),Messages.ui(digit),
			HORIZONTAL_ALIGNMENT_CENTER, 38, 32, Color("142238"))
	var center := Vector2(size.x * 0.49, 245)
	draw_circle(center, 88, Color("203958"))
	draw_arc(center, 88, 0, TAU, 48, Color("bd914d"), 3.0)
	for index in range(6):
		var angle := -PI / 2.0 + float(index) * TAU / 6.0
		var point := center + Vector2.from_angle(angle) * 64.0
		draw_circle(point, 24, Color("deb76d") if index == selected_option else Color("0b1c32"))
		draw_arc(point, 24, 0, TAU, 24, Color("e8c887"), 2.0)
		draw_string(font, point + Vector2(-13, 9),Messages.ui(str(index + 1)),
			HORIZONTAL_ALIGNMENT_CENTER, 26, 26,
			Color("102138") if index == selected_option else Color("fff0d5"))
	for pair in [[6, "CONFIRM", 140], [7, "CLEAR", 205]]:
		var active: bool = selected_option == pair[0]
		var box := Rect2(size.x - 134, pair[2], 110, 49)
		draw_rect(box, Color("deb76d") if active else Color("243b56"))
		draw_rect(box, Color("e8c887"), false, 2.0)
		draw_string(font, box.position + Vector2(8, 32),Messages.ui(pair[1]),
			HORIZONTAL_ALIGNMENT_CENTER, 94, 17,
			Color("102138") if active else Color("fff0d5"))
	if not feedback.is_empty():
		draw_string(font, Vector2(28, size.y - 25),Messages.ui(feedback),
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 56, 17, Color("fff0d5"))
