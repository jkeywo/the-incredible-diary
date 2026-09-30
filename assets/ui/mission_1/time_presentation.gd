extends Control
const Messages = preload("res://foundation/message_text.gd")
const Text = preload("res://localisation/source_text.gd")
## Decorative UI time is separate from the voyage clock and recorded history.
var halo := 0.0
var waiting := false
var rewinding := false
var rewind_progress := 0.0
var hour_age := 2.0
var hour_text := ""
var finish_remaining := 0.0
var suppressed := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func announce_hour(hour: int) -> void:
	hour_age = 0.0
	hour_text = "%d:00" % hour

func clear_announcements() -> void:
	hour_age = 2.0
	waiting = false

func advance(delta: float) -> void:
	hour_age += delta
	finish_remaining = maxf(0.0,finish_remaining-delta)
	halo = move_toward(halo,1.0 if (waiting or rewinding) and not suppressed else 0.0,delta/0.15)
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if get_tree().paused: return
	if finish_remaining > 0:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.94,0.87,0.71,0.2*finish_remaining/0.15))
	if suppressed: return
	var pulse := maxf(0.0,1.0-hour_age/0.6)
	var strength := maxf(halo*0.18,pulse*0.4)
	if strength > 0:
		for i in 3:
			draw_arc(Vector2(1076,130),54.0+i*2.0,0,TAU,64,Color(0.91,0.72,0.39,strength/(i+1)),1.0,true)
	var caption := hour_text if hour_age < 1.2 else Text.UI_WAITING_20 if waiting else ""
	if not caption.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(992,222),Messages.ui(caption),HORIZONTAL_ALIGNMENT_CENTER,160,16,Color("f4dfb4"))
	if rewinding:
		for side in 2:
			var x := 0.0 if side == 0 else size.x-12.0
			draw_rect(Rect2(x,0,12,size.y),Color(0.94,0.87,0.71,0.15))
			for i in 3:
				var p := fposmod(rewind_progress*7.0+float(i)/3.0,1.0)
				var width := sin(p*PI)*24.0
				var start := 8.0 if side == 0 else size.x-8.0-width
				draw_rect(Rect2(start,30+i*8,width,size.y-60-i*16),Color(0.94,0.87,0.71,0.12*sin(p*PI)))
