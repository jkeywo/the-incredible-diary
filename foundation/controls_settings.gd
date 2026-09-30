extends VBoxContainer
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
		heading.text = device.capitalize()
		section.add_child(heading)
		if device == "touch":
			var hint := Label.new()
			hint.text = "Movement joystick position"
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
			note.text = "Buttons appear on the opposite side."
			section.add_child(note)
			continue
		for action in bindings.ACTIONS:
			if device == "controller" and action in ["diary_previous", "diary_next"]: continue
			var title := Label.new()
			title.text = bindings.ACTIONS[action]
			section.add_child(title)
			var row := HBoxContainer.new()
			section.add_child(row)
			for slot in 2:
				var button := Button.new()
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				row.add_child(button)
				buttons.append(button)
				binding_buttons.append([button, action, device, slot])
				button.pressed.connect(func(): begin_capture(action, device, slot))
				var clear := Button.new()
				clear.text = "×"
				clear.tooltip_text = "Clear %s %s binding" % [bindings.ACTIONS[action], "primary" if slot == 0 else "alternate"]
				row.add_child(clear)
				buttons.append(clear)
				clear.pressed.connect(func(): bindings.assign(action, device, slot, {}))
		var reset := Button.new()
		reset.text = "Restore %s defaults" % device
		section.add_child(reset)
		buttons.append(reset)
		reset.pressed.connect(func(): bindings.reset_device(device))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	cancel = Button.new()
	cancel.text = "Cancel binding"
	cancel.pressed.connect(cancel_capture)
	add_child(cancel)
	confirm = Button.new()
	confirm.text = "Assign anyway"
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
		item[0].text = ("1: " if item[3] == 0 else "2: ") + text
		item[0].tooltip_text = "%s — %s: %s" % [bindings.ACTIONS[item[1]], "Primary" if item[3] == 0 else "Alternate", text]

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
	status.text = "Release held inputs, then press a %s input (10 seconds)." % device
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
	status.text = ""
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
		status.text = "Binding cancelled: no input received."

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
		status.text = reason
		return
	if not bindings.valid(record, capture.device): return
	pending = record
	var conflicts: PackedStringArray = bindings.conflicts(capture.action, capture.device, capture.slot, record)
	if conflicts.is_empty():
		_accept()
	else:
		status.text = "Already assigned to: %s. Assign anyway?" % ", ".join(conflicts)
		confirm.show()
		confirm.grab_focus()

func _connection_changed(_id: int, connected: bool) -> void:
	if not connected and capture.get("device") == "controller": cancel_capture()
	refresh_devices()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not capture.is_empty(): cancel_capture()
