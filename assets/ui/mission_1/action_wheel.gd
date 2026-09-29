@tool
extends Control
## Two banks of four textured choices, with cyclic paging for longer menus.
signal option_confirmed(index: int, label: String)
const FRAME = preload("res://assets/ui/popup/nine_piece_style.gd")
const BUTTON_SIZE := Vector2(224,48)
var page := 0
var buttons: Array[Button] = []
var indices: Array[int] = []
@export var options := PackedStringArray(["Inspect", "Talk", "Hide Bag"]):
 set(value):
  if options == value: return
  options = value.duplicate()
  page = 0
  selected_index = 0
  if is_node_ready(): _rebuild()
@export var selected_index := 0:
 set(value):
  selected_index = clampi(value,0,maxi(0,indices.size()-1))
  if is_node_ready(): _highlight()

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 size = Vector2(556,216)
 _rebuild()

func _rebuild() -> void:
 for button in buttons:
  remove_child(button)
  button.queue_free()
 buttons.clear()
 indices.clear()
 var paged := options.size()>8
 var start := page*7 if paged else 0
 var finish := mini(start+7,options.size()) if paged else options.size()
 for index in range(start,finish): indices.append(index)
 if paged: indices.append(-1)
 var left_count := ceili(indices.size()/2.0)
 for slot in indices.size():
  var button := Button.new()
  button.mouse_filter = Control.MOUSE_FILTER_STOP
  button.custom_minimum_size = BUTTON_SIZE
  button.size = BUTTON_SIZE
  var right := slot >= left_count
  var row := slot-left_count if right else slot
  var rows := indices.size()-left_count if right else left_count
  var y := (216-(rows*48+(rows-1)*8))/2.0+row*56
  var inset := 14.0 if row == 0 or row == rows-1 else 0.0
  button.position = Vector2(332-inset if right else inset,y)
  button.add_theme_stylebox_override("normal",_frame())
  button.add_theme_stylebox_override("hover",_frame())
  button.add_theme_stylebox_override("pressed",_frame())
  button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
  button.add_theme_font_size_override("font_size",16)
  for color in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
   button.add_theme_color_override(color,Color("fff1d6"))
  var caption := "More…" if indices[slot]<0 else options[indices[slot]]
  button.text = caption if caption == str(slot+1) else "%d  %s" % [slot+1,caption]
  button.tooltip_text = "More…" if indices[slot]<0 else options[indices[slot]]
  button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
  button.pressed.connect(func(): activate_slot(slot))
  button.mouse_entered.connect(func(): selected_index = slot)
  button.focus_entered.connect(func(): selected_index = slot)
  add_child(button)
  buttons.append(button)
 selected_index = mini(selected_index,maxi(0,buttons.size()-1))
 _highlight()

func _frame() -> StyleBox:
 var frame := FRAME.new()
 frame.set_content_margin(SIDE_LEFT,16)
 frame.set_content_margin(SIDE_RIGHT,16)
 frame.set_content_margin(SIDE_TOP,8)
 frame.set_content_margin(SIDE_BOTTOM,8)
 return frame

func _highlight() -> void:
 for slot in buttons.size():
  buttons[slot].self_modulate = Color(1.35,1.25,1.05) if slot == selected_index else Color.WHITE
  buttons[slot].add_theme_color_override("font_color",Color("ffd578") if slot == selected_index else Color("fff1d6"))

func activate_slot(slot: int) -> void:
 if slot < 0 or slot >= indices.size(): return
 selected_index = slot
 var index := indices[slot]
 if index < 0:
  page = (page+1) % ceili(options.size()/7.0)
  selected_index = 0
  _rebuild()
 else: option_confirmed.emit(index,options[index])

func select_from_vector(direction: Vector2) -> void:
 if direction.length_squared()<0.16 or buttons.is_empty(): return
 var best := -INF
 for slot in buttons.size():
  var vector := (buttons[slot].position+BUTTON_SIZE/2-size/2).normalized()
  var score := vector.dot(direction.normalized())
  if score > best:
   best = score
   selected_index = slot

func confirm_selected() -> void:
 activate_slot(selected_index)
