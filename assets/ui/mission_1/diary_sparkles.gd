extends Control
## A pointer-transparent invitation to try the diary's mysterious final action.
var elapsed := 0.0

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
 if not is_visible_in_tree() or get_parent().disabled: return
 elapsed += delta
 queue_redraw()

func _draw() -> void:
 if get_parent().disabled: return
 for i in 14:
  var phase := fposmod(elapsed * 0.55 + float(i)*0.618,1.0)
  var strength := sin(phase*PI)
  var point := Vector2((float(i)+0.5)/14.0*size.x, -5.0 if i%2 == 0 else size.y+5.0)
  point.y -= phase*6.0
  var radius := 1.5+strength*2.5
  var color := Color(1.0,0.77,0.30,strength*0.85)
  draw_colored_polygon(PackedVector2Array([point+Vector2(-radius,0),point+Vector2(0,-radius*1.5),point+Vector2(radius,0),point+Vector2(0,radius*1.5)]),color)
