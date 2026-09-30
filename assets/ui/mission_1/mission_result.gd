@tool
extends Control
const Messages = preload("res://foundation/message_text.gd")
const Text = preload("res://localisation/source_text.gd")
## Outcome wording is supplied by the game from witnessed facts only.

@export var success := false:
	set(value):
		success = value
		if is_node_ready():
			_refresh()
@export var heading := Text.UI_VOYAGE_SUMMARY:
	set(value):
		heading = value
		if is_node_ready():
			_refresh()
@export_multiline var outcome := Text.UI_THE_SIX_HOURS_HAVE_ENDED:
	set(value):
		outcome = value
		if is_node_ready():
			_refresh()
@export_multiline var witnessed_note := Text.UI_ONLY_WHAT_AMELIA_WITNESSED_IS_RECORDED_HERE:
	set(value):
		witnessed_note = value
		if is_node_ready():
			_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	Messages.assign($Heading,"text",heading)
	Messages.assign($Outcome,"text",outcome)
	Messages.assign($WitnessedNote,"text",witnessed_note)
	queue_redraw()


func _draw() -> void:
	var border := Color("c69b59") if success else Color("aa715e")
	var panel := preload("res://assets/ui/popup/nine_piece_style.gd").new()
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	draw_line(Vector2(34, 92), Vector2(size.x - 34, 92), border, 2.0)
	draw_line(Vector2(34, size.y - 88), Vector2(size.x - 34, size.y - 88), border, 2.0)
	draw_circle(Vector2(size.x * 0.5, 92), 5, border)
