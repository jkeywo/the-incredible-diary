@tool
extends Control
## Visual radial prompt. Gameplay supplies visible options and confirms one.

signal option_confirmed(index: int, label: String)

@export var options := PackedStringArray(["Inspect", "Talk", "Hide Bag"]):
	set(value):
		options = value
		selected_index = mini(selected_index, maxi(0, options.size() - 1))
		queue_redraw()
@export var selected_index := 0:
	set(value):
		selected_index = maxi(0, value)
		queue_redraw()


func select_from_vector(direction: Vector2) -> void:
	if direction.length_squared() < 0.16 or options.is_empty():
		return
	var angle := wrapf(direction.angle() + PI / 2.0, 0.0, TAU)
	selected_index = int(round(angle / TAU * options.size())) % options.size()


func confirm_selected() -> void:
	if selected_index < options.size():
		option_confirmed.emit(selected_index, options[selected_index])


func _draw() -> void:
	var center := size * 0.5
	var outer := minf(size.x, size.y) * 0.48
	var inner := outer * 0.36
	if options.is_empty():
		return
	var font := ThemeDB.fallback_font
	var count := options.size()
	for index in range(count):
		var start := -PI / 2.0 + (float(index) - 0.5) * TAU / count
		var finish := -PI / 2.0 + (float(index) + 0.5) * TAU / count
		var points := PackedVector2Array()
		for step in range(15):
			var angle := lerpf(start, finish, float(step) / 14.0)
			points.append(center + Vector2.from_angle(angle) * outer)
		for step in range(14, -1, -1):
			var angle := lerpf(start, finish, float(step) / 14.0)
			points.append(center + Vector2.from_angle(angle) * inner)
		draw_colored_polygon(points, Color("b28239") if index == selected_index else Color("182941"))
		draw_polyline(points + PackedVector2Array([points[0]]), Color("e3bd76"), 2.0)
		var middle := (start + finish) * 0.5
		var label_at := center + Vector2.from_angle(middle) * (inner + outer) * 0.5
		var caption := options[index]
		draw_string(font, label_at + Vector2(-48, 6), caption,
			HORIZONTAL_ALIGNMENT_CENTER, 96, 15,
			Color("142238") if index == selected_index else Color("fff1d0"))
	draw_circle(center, inner - 2.0, Color("0b192d"))
	draw_arc(center, inner - 2.0, 0.0, TAU, 40, Color("e3bd76"), 2.0)
	draw_string(font, center + Vector2(-35, 6), "ACT", HORIZONTAL_ALIGNMENT_CENTER,
		70, 19, Color("f2d99e"))
