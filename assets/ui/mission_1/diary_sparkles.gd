extends Control
## A pointer-transparent invitation to try the diary's mysterious final action.
var elapsed := 0.0

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
 if not is_visible_in_tree(): return
 if not get_parent().disabled: elapsed += delta
 queue_redraw()

func _draw() -> void:
 if get_parent().disabled: return
 var pulse := 0.5+0.5*sin(elapsed*3.0)
 var edge := Rect2(Vector2.ZERO,size).grow(2.0)
 for layer in range(3,0,-1):
  draw_rect(edge.grow(float(layer)*2.0),Color(1.0,0.65,0.12,0.035+0.025*pulse),false,3.0)
 draw_rect(edge,Color(1.0,0.76,0.24,0.65+0.25*pulse),false,2.0)
 for i in 22:
  var phase := fposmod(elapsed * 0.75 + float(i)*0.618,1.0)
  var strength := sin(phase*PI)
  var point := Vector2((float(i)+0.5)/22.0*size.x, 2.0 if i%2 == 0 else size.y-2.0)
  point += Vector2(sin(phase*TAU+float(i))*4.0,-phase*9.0)
  var radius := 3.0+strength*4.0
  draw_circle(point,radius*1.8,Color(1.0,0.64,0.10,strength*0.16))
  draw_circle(point,radius,Color(1.0,0.78,0.25,strength*0.25))
  var color := Color(1.0,0.81,0.32,strength)
  draw_colored_polygon(PackedVector2Array([point+Vector2(-radius,0),point+Vector2(0,-radius*1.5),point+Vector2(radius,0),point+Vector2(0,radius*1.5)]),color)
  draw_circle(point,1.5,Color(1.0,0.97,0.76,strength))
