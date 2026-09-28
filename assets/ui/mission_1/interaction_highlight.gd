@tool
extends Control
## Scalable brackets for the screen-wide available-interactions toggle.

@export var highlighted := true:
	set(value):
		highlighted = value
		queue_redraw()


func _draw() -> void:
	if not highlighted:
		return
	var color := Color("f0c477")
	var corner := minf(size.x, size.y) * 0.23
	var inset := 3.0
	var left := inset
	var top := inset
	var right := size.x - inset
	var bottom := size.y - inset
	for line in [
		[Vector2(left, top + corner), Vector2(left, top), Vector2(left + corner, top)],
		[Vector2(right - corner, top), Vector2(right, top), Vector2(right, top + corner)],
		[Vector2(left, bottom - corner), Vector2(left, bottom), Vector2(left + corner, bottom)],
		[Vector2(right - corner, bottom), Vector2(right, bottom), Vector2(right, bottom - corner)],
	]:
		draw_polyline(PackedVector2Array(line), color, 3.0)
