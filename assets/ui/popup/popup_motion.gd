extends Node
## Fade a Window's canvas children and panel without moving its input targets.
var window: AcceptDialog
var shade: ColorRect
var frame: StyleBox
var tween: Tween
var alpha := 1.0
var closing := false
var previous_focus: WeakRef

func setup(value: AcceptDialog, parent: Node) -> void:
	window = value
	process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(self)
	shade = ColorRect.new()
	shade.color = Color(0.025,0.045,0.07,0.4)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)
	shade.hide()
	frame = window.get_theme_stylebox("panel").duplicate()
	window.add_theme_stylebox_override("panel",frame)
	window.about_to_popup.connect(entrance)
	window.visibility_changed.connect(func():
		if not window.visible and not closing: shade.hide())

func entrance() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: previous_focus = weakref(focus)
	closing = false
	if tween: tween.kill()
	shade.show()
	set_alpha(0.0)
	tween = create_tween()
	tween.tween_method(set_alpha,0.0,1.0,0.15)

func leave(done: Callable) -> void:
	if closing: return
	closing = true
	if tween: tween.kill()
	# AcceptDialog may hide itself before emitting canceled.
	window.show()
	shade.show()
	tween = create_tween()
	tween.tween_method(set_alpha,alpha,0.0,0.12)
	tween.tween_callback(func():
		window.hide()
		shade.hide()
		closing = false
		done.call())

func finish() -> void:
	if tween: tween.kill()
	closing = false
	window.hide()
	shade.hide()
	set_alpha(1.0)

func restore_focus(fallback: Control) -> void:
	var focus = previous_focus.get_ref() if previous_focus != null else null
	if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()
	elif is_instance_valid(fallback): fallback.grab_focus()

func set_alpha(value: float) -> void:
	alpha = value
	shade.modulate.a = value
	frame.set("tint",Color(1,1,1,value))
	frame.emit_changed()
	for child in window.get_children(true):
		if child is CanvasItem: child.modulate.a = value
