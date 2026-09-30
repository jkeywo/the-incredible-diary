extends Control
const Messages = preload("res://foundation/message_text.gd")
const Text = preload("res://localisation/source_text.gd")
## Independent finger capture prevents one thumb from releasing the other.
signal action_pressed(action: String)
signal controls_released
const FRAME = preload("res://assets/ui/popup/nine_piece_style.gd")
const ACTIONS := ["diary","wait","highlight","cancel"]
const LABELS := [Text.UI_DIARY,Text.UI_WAIT,Text.UI_HIGHLIGHT,Text.UI_CANCEL]
const GAME_SIZE := Vector2(1160,740)
var active := false
var gameplay_enabled := false
var modal := false
var movement := Vector2.ZERO
var waiting_active := false:
 set(value):
  waiting_active = value
  queue_redraw()
var tutorial_action := "":
 set(value):
  tutorial_action = value
  queue_redraw()
var fingers: Dictionary = {}
var buttons: Dictionary = {}
var move_center := Vector2.ZERO
var radius := 72.0
var portrait := false
var top_edge := 0.0
var side_margin := 0.0
var _resizing := false
var _owns_layout := false

static func supported() -> bool:
 if OS.has_feature("web"):
  return DisplayServer.is_touchscreen_available() or bool(JavaScriptBridge.eval(Text.UI_NAVIGATOR_MAXTOUCHPOINTS_0_MATCHMEDIA_POINTER_COARSE_MATCHES))
 return OS.has_feature("android") or OS.has_feature("ios")

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 active = supported()
 get_viewport().size_changed.connect(_resize)
 get_node("/root/AudioSettings").controls_changed.connect(_resize)
 _resize()

func _resize() -> void:
 if _resizing: return
 _resizing = true
 release_all()
 var view := GAME_SIZE
 size = view
 var window := get_tree().root.size
 portrait = window.y>window.x
 if OS.has_feature("web"): portrait = bool(JavaScriptBridge.eval(Text.UI_MATCHMEDIA_ORIENTATION_PORTRAIT_MATCHES))
 radius = minf(110 if portrait else 72,view.x*0.14)
 var available_margin := (float(window.x)*view.y/maxf(window.y,1)-view.x)/2
 side_margin = available_margin if active and not portrait and available_margin >= radius*2+36 else 0.0
 _apply_screen_layout()
 move_center = Vector2(radius+28,view.y-150)
 buttons.clear()
 var font := ThemeDB.fallback_font
 var font_size := 36 if portrait else 18
 var width := 0.0
 for label in LABELS:
  width = maxf(width,font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
 width = ceilf(width)+24
 var height := maxf(44,ceilf(font.get_height(font_size))+16)
 var first_x := view.x-2*width-8-12
 var first_y := view.y-2*height-8-12
 top_edge = minf(move_center.y-radius,first_y)
 for i in ACTIONS.size():
  buttons[ACTIONS[i]] = Rect2(first_x+(i%2)*(width+8),first_y+floori(float(i)/2)*(height+8),width,height)
 if get_node("/root/AudioSettings").stick_on_right:
  move_center.x = view.x-move_center.x
  for action in ACTIONS:
   buttons[action].position.x -= first_x-12
 if side_margin > 0:
  var right: bool = get_node("/root/AudioSettings").stick_on_right
  move_center.x = view.x+side_margin/2 if right else -side_margin/2
  var button_x := -side_margin/2-width/2 if right else view.x+side_margin/2-width/2
  for i in ACTIONS.size():
   buttons[ACTIONS[i]] = Rect2(button_x,view.y-12-4*height-3*8+i*(height+8),width,height)
  top_edge = view.y-40
 queue_redraw()
 _resizing = false

func _apply_screen_layout() -> void:
 if side_margin == 0 and not _owns_layout: return
 _owns_layout = side_margin > 0
 var window := get_tree().root
 window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if _owns_layout else Window.CONTENT_SCALE_ASPECT_KEEP
 window.canvas_transform = Transform2D(0,Vector2(side_margin,0))
 get_canvas_layer_node().offset.x = side_margin
 get_node("/root/AudioSettings").offset.x = side_margin

func _exit_tree() -> void:
 _resizing = true
 if _owns_layout:
  side_margin = 0
  _apply_screen_layout()

func set_context(enabled: bool, blocked: bool) -> void:
 if gameplay_enabled != enabled or modal != blocked: release_all()
 gameplay_enabled = enabled
 modal = blocked
 visible = active and enabled
 queue_redraw()

func release_all() -> void:
 fingers.clear()
 movement = Vector2.ZERO
 controls_released.emit()
 queue_redraw()

func _process(_delta: float) -> void:
 if get_tree().paused and not fingers.is_empty(): release_all()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT: release_all()

func _allowed(action: String) -> bool:
 return not modal or action in ["diary","cancel"]

func _input(event: InputEvent) -> void:
 if not event is InputEventScreenTouch and not event is InputEventScreenDrag: return
 if not active:
  active = true
  visible = gameplay_enabled
  _resize()
 if not gameplay_enabled or get_tree().paused: return
 var id: int = event.index
 var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
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
   elif not event.canceled and buttons[action].has_point(point): action_pressed.emit(action)
   get_viewport().set_input_as_handled()
   queue_redraw()
   return
 if not fingers.has(id): return
 var held: String = fingers[id]
 if held == "move": movement = _vector(point-move_center)
 get_viewport().set_input_as_handled()
 queue_redraw()

func _vector(delta: Vector2) -> Vector2:
 var value := delta/radius
 return Vector2.ZERO if value.length()<0.15 else value.limit_length()

func _draw() -> void:
 if not active or not gameplay_enabled: return
 if side_margin > 0:
  draw_rect(Rect2(-side_margin,0,side_margin,GAME_SIZE.y),Color("09121e"))
  draw_rect(Rect2(GAME_SIZE.x,0,side_margin,GAME_SIZE.y),Color("09121e"))
 var font := ThemeDB.fallback_font
 if not modal:
  for item in [[move_center,movement,"Move"]]:
   var center: Vector2 = item[0]
   draw_circle(center,radius,Color(0.04,0.09,0.15,0.68))
   draw_arc(center,radius,0,TAU,48,Color("cba261"),3,true)
   draw_circle(center+item[1]*radius*0.65,radius*0.36,Color(0.82,0.65,0.38,0.85))
   draw_string(font,center+Vector2(-40,radius+26),Messages.ui(item[2]),HORIZONTAL_ALIGNMENT_CENTER,80,18,Color("fff1d6"))
 for i in ACTIONS.size():
  var action: String = ACTIONS[i]
  if not _allowed(action): continue
  var rect: Rect2 = buttons[action]
  draw_style_box(FRAME.new(),rect)
  if fingers.values().has(action) or (action == "wait" and waiting_active): draw_rect(rect,Color(1.0,0.8,0.4,0.18))
  if action == tutorial_action: draw_rect(rect.grow(3),Color("ffd578"),false,3)
  var color := Color("ffd578") if fingers.values().has(action) else Color("fff1d6")
  var caption: String = Text.UI_STOP_WAITING if action == "wait" and waiting_active else LABELS[i]
  draw_string(font,rect.position+Vector2(4,rect.size.y/2+12 if portrait else rect.size.y/2+6),Messages.ui(caption),HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-8,36 if portrait else 18,color)
