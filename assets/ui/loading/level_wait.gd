extends Control
## Full-size diary, matching the title book, with moving paper and real progress.
const BOOK = preload("res://assets/ui/mission_1/diary_open.png")
var elapsed := 0.0
var progress := 0.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
func _draw() -> void:
	var factor := size / Vector2(1160,740)
	draw_set_transform(Vector2.ZERO,0.0,factor)
	draw_rect(Rect2(0,0,1160,740),Color("0b1723"))
	draw_texture_rect(BOOK,Rect2(0,0,1160,740),false)
	for i in 3:
		var phase := fmod(elapsed/0.72+float(i)/3.0,1.0)
		var width := cos(phase*PI)*407.0
		var lift := sin(phase*PI)*35.0
		var page := PackedVector2Array([Vector2(580,115),Vector2(580+width,130-lift),Vector2(580+width,599-lift),Vector2(580,620)])
		draw_colored_polygon(page,Color("ead7b0") if width > 0 else Color("d8c296"))
		for line in 12:
			var y := 180.0+line*29.0
			draw_line(Vector2(580+width*0.12,y-lift*0.12),Vector2(580+width*0.85,y-lift*0.85),Color(0.43,0.32,0.19,0.18),1.0)
	draw_rect(Rect2(350,625,460,66),Color("0b1723"))
	draw_string(ThemeDB.fallback_font,Vector2(350,650),"Loading the voyage… %d%%" % int(progress*100),HORIZONTAL_ALIGNMENT_CENTER,460,20,Color("eedbb5"))
	draw_rect(Rect2(370,665,420,12),Color("463d2e"))
	draw_rect(Rect2(370,665,420*progress,12),Color("d2ae70"))
