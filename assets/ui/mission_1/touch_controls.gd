extends Control
## Independent finger capture prevents one thumb from releasing the other.
signal action_pressed(action: String)
const FRAME = preload("res://assets/ui/popup/nine_piece_style.gd")
const ACTIONS := ["diary","wait","rewind","highlight","cancel"]
const LABELS := ["Diary","Wait","Rewind","Highlight","Cancel"]
var active := false
var gameplay_enabled := false
var modal := false
var movement := Vector2.ZERO
var wait_held := false
var fingers: Dictionary = {}
var buttons: Dictionary = {}
var move_center := Vector2.ZERO
var radius := 72.0
var portrait := false
var top_edge := 0.0

static func supported() -> bool:
 if OS.has_feature("web"):
  return DisplayServer.is_touchscreen_available() or bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0 && matchMedia('(pointer: coarse)').matches"))
 return OS.has_feature("android") or OS.has_feature("ios")

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 active = supported()
 get_viewport().size_changed.connect(_resize)
 _resize()

func _resize() -> void:
 release_all()
 var view := get_viewport_rect().size
 size = view
 var window := DisplayServer.window_get_size()
 portrait = window.y>window.x
 if OS.has_feature("web"): portrait = bool(JavaScriptBridge.eval("matchMedia('(orientation: portrait)').matches"))
 radius = minf(110 if portrait else 72,view.x*0.14)
 move_center = Vector2(radius+28,view.y-150)
 buttons.clear()
 var margin := radius*2+40
 var columns := 3 if portrait else ACTIONS.size()
 var width := (view.x-margin-20)/columns
 var height := 132.0 if portrait else 68.0
 var rows := 2 if portrait else 1
 var first_y := view.y-rows*(height+8)-12
 top_edge = minf(move_center.y-radius,first_y)
 for i in ACTIONS.size():
  buttons[ACTIONS[i]] = Rect2(margin+(i%columns)*width,first_y+floori(float(i)/columns)*(height+8),width-8,height)
 queue_redraw()

func set_context(enabled: bool, blocked: bool) -> void:
 if gameplay_enabled != enabled or modal != blocked: release_all()
 gameplay_enabled = enabled
 modal = blocked
 visible = active and enabled
 queue_redraw()

func release_all() -> void:
 fingers.clear()
 movement = Vector2.ZERO
 wait_held = false
 queue_redraw()

func _process(_delta: float) -> void:
 if get_tree().paused and not fingers.is_empty(): release_all()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT: release_all()

func _allowed(action: String) -> bool:
 return not modal or action in ["diary","rewind","cancel"]

func _input(event: InputEvent) -> void:
 if not event is InputEventScreenTouch and not event is InputEventScreenDrag: return
 if not active:
  active = true
  visible = gameplay_enabled
 if not gameplay_enabled or get_tree().paused: return
 var id: int = event.index
 var point: Vector2 = event.position
 if event is InputEventScreenTouch:
  if event.pressed:
   if not modal and point.distance_to(move_center) <= radius+18 and not fingers.values().has("move"):
    fingers[id] = "move"
   else:
    for action in ACTIONS:
     if _allowed(action) and buttons[action].has_point(point) and not fingers.values().has(action):
      fingers[id] = action
      break
  elif fingers.has(id):
   var action: String = fingers[id]
   fingers.erase(id)
   if action == "move": movement = Vector2.ZERO
   elif action == "wait": wait_held = false
   elif not event.canceled and buttons[action].has_point(point): action_pressed.emit(action)
   get_viewport().set_input_as_handled()
   queue_redraw()
   return
 if not fingers.has(id): return
 var held: String = fingers[id]
 if held == "move": movement = _vector(point-move_center)
 elif held == "wait": wait_held = buttons.wait.has_point(point)
 get_viewport().set_input_as_handled()
 queue_redraw()

func _vector(delta: Vector2) -> Vector2:
 var value := delta/radius
 return Vector2.ZERO if value.length()<0.15 else value.limit_length()

func _draw() -> void:
 if not active or not gameplay_enabled: return
 var font := ThemeDB.fallback_font
 if not modal:
  for item in [[move_center,movement,"Move"]]:
   var center: Vector2 = item[0]
   draw_circle(center,radius,Color(0.04,0.09,0.15,0.68))
   draw_arc(center,radius,0,TAU,48,Color("cba261"),3,true)
   draw_circle(center+item[1]*radius*0.65,radius*0.36,Color(0.82,0.65,0.38,0.85))
   draw_string(font,center+Vector2(-40,radius+26),item[2],HORIZONTAL_ALIGNMENT_CENTER,80,18,Color("fff1d6"))
 for i in ACTIONS.size():
  var action: String = ACTIONS[i]
  if not _allowed(action): continue
  var rect: Rect2 = buttons[action]
  draw_style_box(FRAME.new(),rect)
  var color := Color("ffd578") if fingers.values().has(action) else Color("fff1d6")
  draw_string(font,rect.position+Vector2(4,rect.size.y/2+12 if portrait else rect.size.y/2+6),LABELS[i],HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-8,36 if portrait else 18,color)
