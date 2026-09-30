extends VBoxContainer
const Messages = preload("res://foundation/message_text.gd")
const Text = preload("res://localisation/source_text.gd")
## Device sections share one scroll area; unavailable devices retain their data.
var keyboard_available := false
var touch_available := false
var sections: Dictionary = {}
var buttons: Array[Control] = []
var binding_buttons: Array = []
var stick_side: OptionButton
var scroll: ScrollContainer
var status: Label
var cancel: Button
var confirm: Button
var capture: Dictionary = {}
var pending: Dictionary = {}
var timeout := 0.0
var armed := false
var neutral: Dictionary = {}
var bindings: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bindings = get_node("/root/InputBindings")
	touch_available = preload("res://assets/ui/mission_1/touch_controls.gd").supported() or DisplayServer.is_touchscreen_available()
	keyboard_available = OS.has_feature("windows") or not touch_available
	scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 240)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	for device in ["keyboard", "controller", "touch"]:
		var section := VBoxContainer.new()
		body.add_child(section)
		sections[device] = section
		var heading := Label.new()
		Messages.assign(heading,"text",device.capitalize())
		section.add_child(heading)
		if device == "touch":
			var hint := Label.new()
			Messages.assign(hint,"text",Text.UI_MOVEMENT_JOYSTICK_POSITION)
			section.add_child(hint)
			stick_side = OptionButton.new()
			stick_side.add_item("Left")
			stick_side.add_item("Right")
			section.add_child(stick_side)
			buttons.append(stick_side)
			stick_side.item_selected.connect(func(index):
				var settings := get_node("/root/AudioSettings")
				settings.set_stick_on_right(index == 1)
				settings.save_settings())
			var note := Label.new()
			Messages.assign(note,"text",Text.UI_BUTTONS_APPEAR_ON_THE_OPPOSITE_SIDE)
			section.add_child(note)
			continue
		for action in bindings.ACTIONS:
			if device == "controller" and action in ["diary_previous", "diary_next"]: continue
			var title := Label.new()
			Messages.assign(title,"text",bindings.ACTIONS[action])
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			section.add_child(row)
			title.custom_minimum_size.x = 240
			row.add_child(title)
			for slot in 2:
				var button := Button.new()
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				row.add_child(button)
				buttons.append(button)
				binding_buttons.append([button, action, device, slot])
				button.pressed.connect(func(): begin_capture(action, device, slot))
				var clear := Button.new()
				Messages.assign(clear,"text","×")
				Messages.assign(clear,"tooltip_text",Text.UI_CLEAR_S_S_BINDING % [bindings.ACTIONS[action], "primary" if slot == 0 else "alternate"])
				row.add_child(clear)
				buttons.append(clear)
				clear.pressed.connect(func(): bindings.assign(action, device, slot, {}))
		var reset := Button.new()
		Messages.assign(reset,"text",Text.UI_RESTORE_S_DEFAULTS % device)
		section.add_child(reset)
		buttons.append(reset)
		reset.pressed.connect(func(): bindings.reset_device(device))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	cancel = Button.new()
	Messages.assign(cancel,"text",Text.UI_CANCEL_BINDING)
	cancel.pressed.connect(cancel_capture)
	add_child(cancel)
	confirm = Button.new()
	Messages.assign(confirm,"text",Text.UI_ASSIGN_ANYWAY)
	confirm.pressed.connect(_accept)
	add_child(confirm)
	bindings.bindings_changed.connect(refresh_labels)
	Input.joy_connection_changed.connect(_connection_changed)
	refresh_labels()
	refresh_devices()
	cancel.hide()
	confirm.hide()

func refresh_labels() -> void:
	for item in binding_buttons:
		var text: String = bindings.label(bindings.bindings[item[1]][item[2]][item[3]])
		Messages.assign_ref(item[0],"text",Messages.make_ref("UI_BINDING_SLOT",{"slot":int(item[3])+1,"binding":Messages.capture(text)}))
		Messages.assign_ref(item[0],"tooltip_text",Messages.make_ref("UI_BINDING_TOOLTIP",{"action":Messages.capture(bindings.ACTIONS[item[1]]),"slot":Messages.capture(Text.UI_PRIMARY if item[3] == 0 else Text.UI_ALTERNATE),"binding":Messages.capture(text)}))

func refresh_devices() -> void:
	if sections.is_empty(): return
	sections.keyboard.visible = keyboard_available
	sections.controller.visible = not Input.get_connected_joypads().is_empty()
	sections.touch.visible = touch_available
	stick_side.select(1 if get_node("/root/Preferences").stick_on_right else 0)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and not focus.is_visible_in_tree():
		var available := choices()
		if not available.is_empty(): available[0].grab_focus()

func choices() -> Array:
	if not capture.is_empty(): return [confirm, cancel] if confirm.visible else [cancel]
	return buttons.filter(func(button): return button.is_visible_in_tree())

func observe_device(event: InputEvent) -> void:
	# Virtual keyboard text/IME has no physical keycode.
	if event is InputEventKey and event.physical_keycode != 0 and not keyboard_available:
		keyboard_available = true
		refresh_devices()
	if event is InputEventScreenTouch and not touch_available:
		touch_available = true
		refresh_devices()

func begin_capture(action: String, device: String, slot: int) -> void:
	capture = {"action": action, "device": device, "slot": slot}
	pending = {}
	neutral = {}
	for id in Input.get_connected_joypads():
		for axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]: neutral[str(id)+":"+str(axis)] = Input.get_joy_axis(id, axis) < 0.2
	timeout = 10.0
	armed = false
	bindings.capture_active = true
	Messages.assign(status,"text",Text.UI_RELEASE_HELD_INPUTS_THEN_PRESS_A_S_INPUT_10_SECONDS % device)
	cancel.show()
	confirm.hide()
	cancel.grab_focus()
	for button in buttons: button.set("disabled", true)

func cancel_capture() -> void:
	capture = {}
	pending = {}
	bindings.capture_active = false
	bindings.guard_release()
	cancel.hide()
	confirm.hide()
	Messages.assign(status,"text","")
	for button in buttons: button.set("disabled", false)
	var available := choices()
	if not available.is_empty(): available[0].grab_focus()

func _accept() -> void:
	if capture.is_empty() or pending.is_empty(): return
	bindings.assign(capture.action, capture.device, capture.slot, pending)
	cancel_capture()

func _process(delta: float) -> void:
	if capture.is_empty(): return
	if not armed and not Input.is_anything_pressed(): armed = true
	if not pending.is_empty(): return
	timeout -= delta
	if timeout <= 0:
		cancel_capture()
		Messages.assign(status,"text",Text.UI_BINDING_CANCELLED_NO_INPUT_RECEIVED)

func _input(event: InputEvent) -> void:
	observe_device(event)
	if capture.is_empty(): return
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag: return
	get_viewport().set_input_as_handled()
	if not pending.is_empty():
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_A: _accept()
			elif event.button_index == JOY_BUTTON_B: cancel_capture()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ENTER: _accept()
			elif event.keycode == KEY_ESCAPE: cancel_capture()
		return
	if not armed or event.is_echo(): return
	if capture.device == "keyboard" and not event is InputEventKey: return
	if capture.device == "controller" and not (event is InputEventJoypadButton or event is InputEventJoypadMotion): return
	if event is InputEventJoypadMotion:
		var id := str(event.device)+":"+str(event.axis)
		if event.axis_value < 0.2: neutral[id] = true
		if event.axis not in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] or event.axis_value < 0.5 or not neutral.get(id, false): return
	elif not event.is_pressed(): return
	var record: Dictionary = bindings.from_event(event)
	if record.is_empty(): return
	var reason: String = bindings.reserved(record)
	if not reason.is_empty():
		Messages.assign(status,"text",reason)
		return
	if not bindings.valid(record, capture.device): return
	pending = record
	var conflicts: PackedStringArray = bindings.conflicts(capture.action, capture.device, capture.slot, record)
	if conflicts.is_empty():
		_accept()
	else:
		Messages.assign(status,"text",Text.UI_ALREADY_ASSIGNED_TO_S_ASSIGN_ANYWAY % ", ".join(conflicts))
		confirm.show()
		confirm.grab_focus()

func _connection_changed(_id: int, connected: bool) -> void:
	if not connected and capture.get("device") == "controller": cancel_capture()
	refresh_devices()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not capture.is_empty(): cancel_capture()
