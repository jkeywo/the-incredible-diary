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
 assert(controls.visible and controls.buttons.size()==5)
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
 game.queue_free()
 await process_frame
 print("TOUCH CONTROLS PASS: movement, simultaneous option taps, independent release, hold, cancel, diary, focus and settings pause")
 quit()
