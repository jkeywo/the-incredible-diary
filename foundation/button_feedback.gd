extends Node
const CLICK = preload("res://assets/audio/mission_1/sfx/control_button.wav")
var sound: AudioStreamPlayer
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 sound = AudioStreamPlayer.new()
 sound.stream = CLICK
 sound.bus = &"SFX"
 sound.volume_db = -22
 sound.max_polyphony = 6
 add_child(sound)
 get_tree().node_added.connect(_added)
 _scan(get_tree().root)
func _scan(node: Node) -> void:
 _added(node)
 for child in node.get_children(): _scan(child)
func _added(node: Node) -> void:
 if node is BaseButton: call_deferred("_attach",node)
func _attach(button: BaseButton) -> void:
 if not is_instance_valid(button) or button.has_meta("button_feedback"): return
 button.set_meta("button_feedback",true)
 button.mouse_entered.connect(func(): _tint(button,Color(1.0,0.88,0.65)))
 button.mouse_exited.connect(func(): _tint(button,Color.WHITE))
 button.focus_entered.connect(func(): _tint(button,Color(1.0,0.88,0.65)))
 button.focus_exited.connect(func(): _tint(button,Color.WHITE))
 button.button_down.connect(func(): _tint(button,Color(0.8,0.85,0.9)))
 button.button_up.connect(func(): _tint(button,Color.WHITE))
 button.pressed.connect(func():
  if not button.get_meta("custom_feedback",false): activate(button))
func _tint(button: BaseButton, color: Color) -> void:
 if not is_instance_valid(button) or button.disabled: return
 var previous: Tween = button.get_meta("feedback_tween") if button.has_meta("feedback_tween") else null
 if previous and previous.is_valid(): previous.kill()
 var tween := button.create_tween()
 button.set_meta("feedback_tween",tween)
 tween.tween_property(button,"modulate",color,0.09)
func activate(button: BaseButton = null) -> void:
 sound.pitch_scale = randf_range(0.94,1.06)
 sound.play()
 if is_instance_valid(button):
  button.modulate = Color(0.8,0.85,0.9)
  _tint(button,Color.WHITE)
