@tool
extends Control
## First-playable visual HUD; simulation owns time and supplies these values.

@export_range(1, 6, 1) var hour := 1:
	set(value):
		hour = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var hour_progress := 0.0:
	set(value):
		hour_progress = value
		queue_redraw()
@export_range(-1.0, 1.0, 0.01) var action_progress := -1.0:
	set(value):
		action_progress = value
		queue_redraw()
@export var diary_cue := false:
	set(value):
		diary_cue = value
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var face := Vector2(55, 56)
	draw_circle(face, 48, Color("0d1c31"))
	draw_arc(face, 48, 0, TAU, 64, Color("d7ad68"), 4.0)
	for mark in range(12):
		var angle := -PI / 2.0 + float(mark) * TAU / 12.0
		var vector := Vector2.from_angle(angle)
		draw_line(face + vector * 35, face + vector * 41,
			Color("f0d198"), 2.0)
	var hand := Vector2.from_angle(-PI / 2.0 + hour_progress * TAU)
	draw_line(face, face + hand * 30, Color("f5e5b9"), 3.0)
	draw_circle(face, 4, Color("f5e5b9"))
	draw_string(font, Vector2(119, 43), "HOUR %d" % hour,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("f1d49a"))
	draw_string(font, Vector2(120, 72), "THE VOYAGE", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 14, Color("fff1d0"))
	if diary_cue:
		draw_rect(Rect2(272, 20, 30, 39), Color("c59549"))
		draw_rect(Rect2(277, 23, 22, 33), Color("132b46"))
		draw_line(Vector2(287, 32), Vector2(290, 47), Color("f3dc9f"), 2.0)
	if action_progress >= 0.0:
		draw_rect(Rect2(120, 83, 183, 11), Color("1a2b41"))
		draw_rect(Rect2(120, 83, 183 * action_progress, 11), Color("e6bb73"))
		draw_rect(Rect2(120, 83, 183, 11), Color("f3dc9f"), false, 1.0)
