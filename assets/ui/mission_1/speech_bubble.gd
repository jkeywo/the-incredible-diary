@tool
extends Control
## Resize bubble_size or the Control rect; text wraps inside the paper panel.

@export var bubble_size := Vector2(320, 132):
 set(value):
  bubble_size = Vector2(maxf(value.x, 170.0), maxf(value.y, 84.0))
  if is_node_ready():
   size = bubble_size
   _layout_text()
   queue_redraw()
@export_range(0.15, 0.85, 0.01) var tail_position := 0.5:
 set(value):
  tail_position = value
  queue_redraw()
@export var speaker_name := "Passenger":
 set(value):
  speaker_name = value
  if is_node_ready():
   _layout_text()
@export_multiline var message := "We should look more closely.":
 set(value):
  message = value
  if is_node_ready():
   _layout_text()

const PAPER = preload("res://assets/ui/popup/body.png")
const FRAME = preload("res://assets/ui/popup/nine_piece_style.gd")
var tail_side := "bottom"
var kind := "speech"

func point_tail_at(target: Vector2) -> void:
 var center := Vector2(size.x/2,(size.y-20)/2)
 var delta := target-center
 if absf(delta.x)/(size.x/2) > absf(delta.y)/maxf(1,center.y):
  tail_side = "right" if delta.x>0 else "left"
  tail_position = clampf(target.y/(size.y-20),0.15,0.85)
 else:
  tail_side = "bottom" if delta.y>0 else "top"
  tail_position = clampf(target.x/size.x,0.15,0.85)
 queue_redraw()

func tail_geometry() -> Array[Vector2]:
 var edge := Vector2(size.x*tail_position,size.y-20)
 var direction := Vector2.DOWN
 match tail_side:
  "top": edge = Vector2(size.x*tail_position,0); direction = Vector2.UP
  "left": edge = Vector2(0,(size.y-20)*tail_position); direction = Vector2.LEFT
  "right": edge = Vector2(size.x,(size.y-20)*tail_position); direction = Vector2.RIGHT
 return [edge,direction]

var background_opacity := 1.0:
 set(value):
  background_opacity = value
  self_modulate.a = value
  queue_redraw()

func present(line: Dictionary, elapsed_seconds: float) -> void:
 speaker_name = line.get("name", "Passenger")
 message = line.get("text", "")
 kind = line.get("kind", "speech")
 message_label.visible_characters = mini(message.length(), maxi(0, int(elapsed_seconds * 36.0)))
 queue_redraw()

@onready var speaker_label: Label = $Speaker
@onready var message_label: Label = $Message


func _ready() -> void:
 custom_minimum_size = Vector2(170, 84)
 size = bubble_size
 speaker_label.add_theme_color_override("font_color", Color("e6c68c"))
 message_label.add_theme_color_override("font_color", Color("fff1d6"))
 _layout_text()
 queue_redraw()


func _notification(what: int) -> void:
 if what == NOTIFICATION_RESIZED:
  if is_node_ready():
   _layout_text()
  queue_redraw()


func _layout_text() -> void:
 speaker_label.text = speaker_name
 speaker_label.visible = not speaker_name.is_empty()
 speaker_label.position = Vector2(26, 13)
 speaker_label.size = Vector2(size.x - 52, 26)
 message_label.text = message
 message_label.position = Vector2(26, 40 if speaker_label.visible else 20)
 message_label.size = Vector2(size.x - 52, size.y - message_label.position.y - 34)


func _textured_shape(points: PackedVector2Array) -> void:
 var uv := PackedVector2Array()
 for p in points: uv.append(p / Vector2(PAPER.get_size()))
 draw_polygon(points,PackedColorArray([Color.WHITE]),uv,PAPER)
 var outline := points.duplicate()
 outline.append(points[0])
 draw_polyline(outline,Color("ba955c"),2.0)

func _thought_dot(center: Vector2, radius: float) -> void:
 var points := PackedVector2Array()
 for i in 24: points.append(center+Vector2.from_angle(TAU*i/24.0)*radius)
 _textured_shape(points)

func _draw() -> void:
 var tail := tail_geometry()
 var edge: Vector2 = tail[0]
 var direction: Vector2 = tail[1]
 var tangent := direction.orthogonal()*13
 if kind == "thought":
  # A cloud silhouette and trailing beads distinguish unspoken thoughts.
  var cloud := PackedVector2Array()
  var center := Vector2(size.x/2,(size.y-26)/2)
  for i in 120:
   var angle := TAU*i/120.0
   var radius := 1.0 + 0.035*cos(angle*12)
   var x := signf(cos(angle))*pow(absf(cos(angle)),0.45)
   var y := signf(sin(angle))*pow(absf(sin(angle)),0.65)
   cloud.append(center+Vector2(x*(size.x/2-7),y*(size.y-34)/2)*radius)
  _textured_shape(cloud)
  _thought_dot(edge+direction*5,6)
  _thought_dot(edge+direction*20,3)
 else:
  _textured_shape(PackedVector2Array([edge-tangent-direction*3,edge+direction*20,edge+tangent-direction*3]))
  draw_style_box(FRAME.new(),Rect2(0,0,size.x,size.y-20))
