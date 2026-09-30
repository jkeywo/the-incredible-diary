extends SceneTree
const Play = preload("res://mission1/play.tscn")
func _initialize(): call_deferred("checks")
func touch(id: int, point: Vector2, pressed: bool, canceled := false):
 var event := InputEventScreenTouch.new()
 event.index = id
 event.position = point
 event.pressed = pressed
 event.canceled = canceled
 root.push_input(event,true)
func checks():
 var game = Play.instantiate()
 game.sim = preload("res://mission1/simulation.gd").new(false)
 game.configure({},false)
 root.add_child(game)
 game.enable_controls()
 game.set_physics_process(false)
 var controls = game.touch_controls
 controls.active = true
 game.sim.s.pos = [145,390]
 game._refresh()
 await process_frame
 assert(controls.visible and controls.buttons.size()==4)
 assert(not controls.buttons.has("rewind"))
 assert(controls.buttons.diary.position.y == controls.buttons.wait.position.y)
 assert(controls.buttons.highlight.position.y == controls.buttons.cancel.position.y)
 assert(controls.buttons.diary.position.x == controls.buttons.highlight.position.x)
 assert(controls.buttons.wait.position.x == controls.buttons.cancel.position.x)
 assert(not controls.buttons.has("interact") and not controls.buttons.has("pause"))
 var thumb: Vector2 = controls.move_center+Vector2(60,0)
 touch(0,thumb,true)
 assert(controls.movement.x > 0.7)
 var before: float = game.sim.s.pos[0]
 game._physics_process(0.1)
 assert(game.sim.s.pos[0] > before)
 var option: Vector2 = game.wheel.buttons[0].get_global_rect().get_center()
 touch(1,option,true)
 touch(1,option,false)
 assert(game.sim.s.action.id == "inspect_bag")
 assert(controls.movement.x>0.7)
 touch(0,thumb,false)
 assert(controls.movement == Vector2.ZERO)
 game.sim.s.action = {}
 var wait_point: Vector2 = controls.buttons.wait.get_center()
 touch(2,wait_point,true)
 assert(controls.wait_held)
 touch(2,Vector2.ZERO,false)
 assert(not controls.wait_held)
 touch(0,thumb,true)
 var diary_point: Vector2 = controls.buttons.diary.get_center()
 touch(3,diary_point,true)
 touch(3,diary_point,false)
 assert(game.diary_open and controls.movement == Vector2.ZERO)
 touch(3,diary_point,true)
 touch(3,diary_point,false)
 game.diary_presentation.advance(0.2)
 assert(not game.diary_open)
 var highlight_point: Vector2 = controls.buttons.highlight.get_center()
 touch(4,highlight_point,true)
 touch(4,highlight_point,false,true)
 assert(not game.highlight)
 touch(4,highlight_point,true)
 touch(4,highlight_point,false)
 assert(game.highlight)
 touch(0,thumb,true)
 paused = true
 await process_frame
 assert(controls.movement == Vector2.ZERO and controls.fingers.is_empty())
 paused = false
 touch(0,thumb,true)
 controls._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 assert(controls.movement == Vector2.ZERO)
 var settings = root.get_node("AudioSettings")
 settings.settings_path = "res://build/touch-settings-test.cfg"
 settings.touch_available = false
 settings._refresh_controls_tab()
 assert(not settings.tabs.is_tab_hidden(settings.controls_tab.get_index()))
 assert(settings.controls_tab.sections.keyboard.visible)
 var detected := InputEventScreenTouch.new()
 detected.pressed = true
 settings._input(detected)
 assert(not settings.tabs.is_tab_hidden(settings.controls_tab.get_index()))
 touch(0,thumb,true)
 settings.stick_side.item_selected.emit(1)
 assert(controls.movement == Vector2.ZERO and controls.fingers.is_empty())
 assert(controls.move_center.x > controls.size.x/2)
 assert(controls.buttons.diary.position.x == 12)
 assert(controls.buttons.wait.position.x > controls.buttons.diary.position.x)
 settings.set_stick_on_right(false)
 settings.load_settings()
 assert(settings.stick_on_right and controls.move_center.x > controls.size.x/2)
 settings.set_stick_on_right(false)
 assert(controls.move_center.x < controls.size.x/2)
 assert(controls.buttons.diary.position.x > controls.size.x/2)
 # A wide viewport exposes real side margins while the scene stays centred.
 root.size = Vector2i(1600,740)
 await process_frame
 await process_frame
 assert(controls.side_margin == 220)
 assert(root.canvas_transform.origin == Vector2(220,0))
 assert(controls.move_center.x < 0)
 for action in controls.ACTIONS:
  assert(controls.buttons[action].position.x > 1160)
 assert(controls.buttons.diary.position.x == controls.buttons.wait.position.x)
 var wide_thumb: Vector2 = controls.get_global_transform_with_canvas()*(controls.move_center+Vector2(60,0))
 touch(0,wide_thumb,true)
 assert(controls.movement.x > 0.7)
 game.sim.s.action = {}
 game._refresh()
 var button: Button = game.wheel.buttons[0]
 var wide_option: Vector2 = button.get_global_transform_with_canvas()*(button.size/2)
 touch(1,wide_option,true)
 touch(1,wide_option,false)
 assert(game.sim.s.action.id == "inspect_bag" and controls.movement.x > 0.7)
 settings.set_stick_on_right(true)
 assert(controls.movement == Vector2.ZERO)
 assert(controls.move_center.x > 1160 and controls.buttons.diary.end.x < 0)
 var wide_wait: Vector2 = controls.get_global_transform_with_canvas()*controls.buttons.wait.get_center()
 touch(2,wide_wait,true)
 assert(controls.wait_held)
 root.size = Vector2i(1280,740)
 await process_frame
 assert(controls.side_margin == 0 and not controls.wait_held)
 assert(root.canvas_transform == Transform2D.IDENTITY)
 assert(controls.buttons.diary.position.y == controls.buttons.wait.position.y)
 root.size = Vector2i(740,1160)
 await process_frame
 assert(controls.portrait and controls.side_margin == 0)
 root.size = Vector2i(1600,740)
 await process_frame
 assert(controls.side_margin > 0)
 DirAccess.remove_absolute(settings.settings_path)
 game.queue_free()
 await process_frame
 assert(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP)
 assert(root.canvas_transform == Transform2D.IDENTITY and settings.offset.x == 0)
 print("TOUCH CONTROLS PASS: input, settings persistence, wide margins, swapping, resize fallback and scene cleanup")
 quit()
