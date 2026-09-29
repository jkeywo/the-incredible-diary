extends Control
## The hands use simulation time, including recorded time during rewind.
const HOUR_SECONDS := 180.0
var elapsed_seconds := 0.0:
	set(value):
		elapsed_seconds = clampf(value, 0.0, HOUR_SECONDS * 6.0)
		queue_redraw()

static func hand_angles(seconds: float) -> Vector2:
	var hours := seconds / HOUR_SECONDS
	return Vector2((1.0 + hours) * TAU / 12.0 - PI / 2.0, fmod(hours, 1.0) * TAU - PI / 2.0)

func _ready() -> void:
	custom_minimum_size = Vector2(132, 168)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c := Vector2(66, 79)
	draw_arc(Vector2(66, 13), 10, 0, TAU, 32, Color("c49b50"), 4, true)
	draw_rect(Rect2(59, 20, 14, 10), Color("d8b86c"))
	draw_circle(c + Vector2(3, 4), 60, Color(0, 0, 0, 0.45))
	draw_circle(c, 59, Color("a87a37"))
	draw_circle(c, 55, Color("eed192"))
	draw_circle(c, 50, Color("eee7ce"))
	for i in 60:
		var direction := Vector2.from_angle(i * TAU / 60.0 - PI / 2.0)
		draw_line(c + direction * (40 if i % 5 == 0 else 45), c + direction * 48, Color("554331"), 2 if i % 5 == 0 else 1, true)
	for i in 12:
		var label := str(12 if i == 0 else i)
		var p := c + Vector2.from_angle(i * TAU / 12.0 - PI / 2.0) * 32
		draw_string(ThemeDB.fallback_font, p + Vector2(-5 if label.length() == 1 else -10, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("302e2a"))
	var angles := hand_angles(elapsed_seconds)
	draw_line(c, c + Vector2.from_angle(angles.x) * 25, Color("25323a"), 5, true)
	draw_line(c, c + Vector2.from_angle(angles.y) * 39, Color("25323a"), 3, true)
	draw_circle(c, 4, Color("a87a37"))
	var hour := mini(6, 1 + int(elapsed_seconds / HOUR_SECONDS))
	draw_style_box(_caption_box(), Rect2(14, 142, 104, 24))
	draw_string(ThemeDB.fallback_font, Vector2(37, 159), "HOUR %d" % hour, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f3dfac"))

func _caption_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("17252deb")
	box.set_corner_radius_all(5)
	return box
