extends Control
const Messages = preload("res://foundation/message_text.gd")
## Device-aware keycaps and left-stick glyph anchored beneath Boy.
var controller := false:
 set(value):
  controller = value
  queue_redraw()
func _ready() -> void:
 get_node("/root/InputBindings").bindings_changed.connect(queue_redraw)

func _draw() -> void:
 var ink := Color("fff1cc")
 if controller:
  draw_circle(Vector2(45,28),23,Color("14222c"))
  draw_arc(Vector2(45,28),23,0,TAU,32,Color("bd9149"),2,true)
  draw_line(Vector2(45,32),Vector2(45,18),ink,5,true)
  draw_circle(Vector2(45,17),8,ink)
  draw_string(ThemeDB.fallback_font,Vector2(77,34),Messages.ui("L"),HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
 else:
  for item in [["move_up",Vector2(34,0)],["move_left",Vector2(0,30)],["move_down",Vector2(34,30)],["move_right",Vector2(68,30)]]:
   var style := StyleBoxFlat.new()
   style.bg_color = Color("14222c")
   style.border_color = Color("bd9149")
   style.set_border_width_all(2)
   style.set_corner_radius_all(4)
   draw_style_box(style,Rect2(item[1],Vector2(29,27)))
   draw_string(ThemeDB.fallback_font,item[1]+Vector2(7,19),Messages.ui(get_node("/root/InputBindings").prompt(item[0])),HORIZONTAL_ALIGNMENT_LEFT,65,12,ink)
