extends Node
## Scoped to one menu/Window so controller input cannot reach gameplay behind it.
var available: Callable
var enabled: Callable
var back: Callable
var change_tab: Callable
var stick := Vector2.ZERO
var direction := Vector2i.ZERO
var repeat_left := 0.0
var device := -1
var start_is_back := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(func(id: int, connected: bool):
		if id == device and not connected: reset())

func reset() -> void:
	stick = Vector2.ZERO
	direction = Vector2i.ZERO
	repeat_left = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: reset()

func _process(delta: float) -> void:
	if not enabled.is_valid() or not enabled.call():
		reset()
		return
	if direction == Vector2i.ZERO: return
	repeat_left -= delta
	if repeat_left <= 0.0:
		navigate(direction)
		repeat_left = 0.12

func _input(event: InputEvent) -> void:
	if not enabled.is_valid() or not enabled.call(): return
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
		device = event.device
		if event.axis == JOY_AXIS_LEFT_X: stick.x = event.axis_value
		else: stick.y = event.axis_value
		var next := Vector2i.ZERO
		if stick.length() >= 0.5:
			next = Vector2i(int(signf(stick.x)),0) if absf(stick.x)>absf(stick.y) else Vector2i(0,int(signf(stick.y)))
		if next != direction:
			direction = next
			repeat_left = 0.35
			if next != Vector2i.ZERO: navigate(next)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_START and not start_is_back: return
		if event.button_index not in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_START,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]: return
		get_viewport().set_input_as_handled()
		if not event.pressed: return
		match event.button_index:
			JOY_BUTTON_A: activate()
			JOY_BUTTON_B,JOY_BUTTON_START:
				reset()
				if back.is_valid(): back.call()
			JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER:
				reset()
				if change_tab.is_valid(): change_tab.call(-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
			JOY_BUTTON_DPAD_UP: navigate(Vector2i.UP)
			JOY_BUTTON_DPAD_DOWN: navigate(Vector2i.DOWN)
			JOY_BUTTON_DPAD_LEFT: navigate(Vector2i.LEFT)
			JOY_BUTTON_DPAD_RIGHT: navigate(Vector2i.RIGHT)

func choices() -> Array:
	var result: Array = []
	if not available.is_valid(): return result
	for control in available.call():
		if not is_instance_valid(control) or not control.is_visible_in_tree(): continue
		if control is BaseButton and control.disabled: continue
		result.append(control)
	return result

func navigate(move: Vector2i) -> void:
	var items := choices()
	if items.is_empty(): return
	var focus := get_viewport().gui_get_focus_owner()
	var index := items.find(focus)
	if index < 0:
		items[0].grab_focus()
		return
	if move.x != 0 and focus is Slider:
		focus.value += move.x*5
		return
	if move.x != 0 and focus is OptionButton:
		select_option(focus,move.x)
		return
	var step := move.y if move.y != 0 else move.x
	items[posmod(index+step,items.size())].grab_focus()

func activate() -> void:
	var items := choices()
	if items.is_empty(): return
	var focus := get_viewport().gui_get_focus_owner()
	if not items.has(focus):
		items[0].grab_focus()
		return
	if focus is OptionButton: select_option(focus,1)
	elif focus is BaseButton: focus.pressed.emit()

func select_option(option: OptionButton, step: int) -> void:
	for offset in range(1,option.item_count+1):
		var index := posmod(option.selected+step*offset,option.item_count)
		if option.is_item_disabled(index): continue
		option.select(index)
		option.item_selected.emit(index)
		return
