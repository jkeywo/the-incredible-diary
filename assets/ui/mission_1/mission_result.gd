@tool
extends Control
## Outcome wording is supplied by the game from witnessed facts only.

@export var success := false:
	set(value):
		success = value
		if is_node_ready():
			_refresh()
@export var heading := "VOYAGE SUMMARY":
	set(value):
		heading = value
		if is_node_ready():
			_refresh()
@export_multiline var outcome := "The six Hours have ended.":
	set(value):
		outcome = value
		if is_node_ready():
			_refresh()
@export_multiline var witnessed_note := "Only what Amelia witnessed is recorded here.":
	set(value):
		witnessed_note = value
		if is_node_ready():
			_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	$Heading.text = heading
	$Outcome.text = outcome
	$WitnessedNote.text = witnessed_note
	queue_redraw()


func _draw() -> void:
	var border := Color("c69b59") if success else Color("aa715e")
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("102138")
	panel.border_color = border
	panel.set_border_width_all(5)
	panel.set_corner_radius_all(13)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	draw_line(Vector2(34, 92), Vector2(size.x - 34, 92), border, 2.0)
	draw_line(Vector2(34, size.y - 88), Vector2(size.x - 34, size.y - 88), border, 2.0)
	draw_circle(Vector2(size.x * 0.5, 92), 5, border)
