extends Node2D
## Small deterministic accents, sampled rather than played independently.
var kind := ""
var age := -1.0

func show_at(effect: String, seconds: float) -> void:
	kind = effect
	age = seconds
	visible = age >= 0.0 and age < (0.8 if kind == "impact" else 0.5)
	queue_redraw()

static func impact_offset(seconds: float) -> Vector2:
	if seconds < 0.0 or seconds >= 0.2: return Vector2.ZERO
	return Vector2(sin(seconds * 95.0), cos(seconds * 80.0)) * (1.4 * (1.0-seconds/0.2))

func _draw() -> void:
	if not visible: return
	var duration := 0.8 if kind == "impact" else 0.5
	var t := age / duration
	for i in (7 if kind == "impact" else 6):
		var side := -1.0 if i % 2 == 0 else 1.0
		var reach := (12.0 + i * 5.0) if kind == "impact" else (5.0 + i * 2.0)
		var p := Vector2(side * reach * t, -sin(t * PI) * (12.0+i*2.0))
		if kind == "spill": p.y -= (1.0-t)*22.0
		var color := Color(0.85,0.76,0.55,1.0-t) if kind == "impact" else Color(0.9,0.8,0.52,0.8*(1.0-t))
		draw_rect(Rect2(p.round(),Vector2(2,2 if kind == "impact" else 3)),color)
