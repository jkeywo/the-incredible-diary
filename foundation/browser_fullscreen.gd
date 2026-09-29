extends CanvasLayer

var toggle: Button

func _ready() -> void:
	if not OS.has_feature("web"):
		return
	layer = 100
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	toggle = Button.new()
	toggle.tooltip_text = "Toggle fullscreen"
	toggle.anchor_left = 1.0
	toggle.anchor_right = 1.0
	toggle.offset_left = -46.0
	toggle.offset_right = -8.0
	toggle.offset_top = 8.0
	toggle.offset_bottom = 46.0
	toggle.pressed.connect(_toggle_fullscreen)
	toggle.draw.connect(_draw_icon)
	overlay.add_child(toggle)

func _toggle_fullscreen() -> void:
	var current := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if current == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _draw_icon() -> void:
	var color := Color("e8f2f6")
	for corner in [Vector2(9, 9), Vector2(29, 9), Vector2(9, 29), Vector2(29, 29)]:
		var x := 1.0 if corner.x < 19.0 else -1.0
		var y := 1.0 if corner.y < 19.0 else -1.0
		toggle.draw_line(corner, corner + Vector2(8.0 * x, 0), color, 2.0)
		toggle.draw_line(corner, corner + Vector2(0, 8.0 * y), color, 2.0)
