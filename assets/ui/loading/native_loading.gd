extends Control
const Messages = preload("res://foundation/message_text.gd")
const Text = preload("res://localisation/source_text.gd")
## Keep the native window responsive while the title's resources load.
const TITLE := "res://assets/ui/mission_1/title_screen.tscn"
const DIARY = preload("res://assets/ui/loading/diary.png")
const GODOT_ICON = preload("res://assets/ui/loading/godot-icon.png")
var elapsed := 0.0
var progress := 0.0
var failed := false
var completed := false
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 ResourceLoader.load_threaded_request(TITLE)
func _process(delta: float) -> void:
 elapsed += delta
 var values := []
 var status := ResourceLoader.load_threaded_get_status(TITLE,values)
 if not values.is_empty(): progress = float(values[0])
 failed = status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
 if status == ResourceLoader.THREAD_LOAD_LOADED and elapsed >= (0.0 if OS.has_feature("web") else 0.85) and not completed:
  completed = true
  var scene: PackedScene = ResourceLoader.load_threaded_get(TITLE)
  get_tree().change_scene_to_packed.call_deferred(scene)
 queue_redraw()
func _draw() -> void:
 var font := ThemeDB.fallback_font
 draw_rect(Rect2(Vector2.ZERO,size),Color("0b1723"))
 draw_rect(Rect2(Vector2(18,18),size-Vector2(36,36)),Color("967442"),false)
 draw_rect(Rect2(Vector2(24,24),size-Vector2(48,48)),Color("473e2f"),false)
 var center := size.x/2
 draw_string(font,Vector2(center-250,150),Messages.ui(Text.UI_A_VOYAGE_BETWEEN_THE_PAGES),HORIZONTAL_ALIGNMENT_CENTER,500,14,Color("c8a669"))
 draw_string(font,Vector2(center-450,205),Messages.ui(Text.UI_THE_INCREDIBLE_DIARY),HORIZONTAL_ALIGNMENT_CENTER,900,36,Color("eedbb5"))
 var spine := Vector2(center,310)
 var source := Vector2(DIARY.get_size())
 draw_set_transform_matrix(Transform2D(Vector2(0.78,0.415),Vector2.DOWN,spine))
 draw_texture_rect_region(DIARY,Rect2(-180,0,180,240),Rect2(Vector2.ZERO,Vector2(source.x/2,source.y)))
 draw_set_transform_matrix(Transform2D(Vector2(0.78,-0.415),Vector2.DOWN,spine))
 draw_texture_rect_region(DIARY,Rect2(0,0,180,240),Rect2(Vector2(source.x/2,0),Vector2(source.x/2,source.y)))
 for i in 3:
  var phase := fmod(elapsed/0.42+float(i)/3,1.0)
  var fan_x := cos(phase*PI)*0.78
  var fan_y := -0.415-sin(phase*PI)*0.235
  draw_set_transform_matrix(Transform2D(Vector2(fan_x,fan_y),Vector2.DOWN,spine+Vector2(0,22)))
  draw_rect(Rect2(0,0,162,168),Color("eed8ac"))
  draw_rect(Rect2(0,0,162,168),Color("b89a65"),false)
  for line in 8: draw_line(Vector2(20,30+line*14),Vector2(140,30+line*14),Color(0.5,0.4,0.25,0.22))
 draw_set_transform_matrix(Transform2D.IDENTITY)
 var text := Text.UI_UNABLE_TO_LOAD_THE_DIARY_PLEASE_RESTART if failed else Text.UI_LOADING_THE_DIARY_D % int(progress*100)
 draw_string(font,Vector2(center-300,595),Messages.ui(text),HORIZONTAL_ALIGNMENT_CENTER,600,18,Color("dcc99f"))
 draw_rect(Rect2(center-170,620,340,19),Color("bb9655"),false)
 draw_rect(Rect2(center-165,625,330*progress,9),Color("d2ae70"))
 draw_string(font,Vector2(size.x-235,size.y-35),Messages.ui(Text.UI_MADE_WITH_GODOT),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("bca77e"))
 draw_texture_rect(GODOT_ICON,Rect2(size.x-68,size.y-62,38,38),false)
