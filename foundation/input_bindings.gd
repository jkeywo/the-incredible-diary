extends Node
const Text = preload("res://localisation/source_text.gd")
signal bindings_changed
const ACTIONS := {
	"move_left": Text.UI_MOVE_LEFT, "move_right": Text.UI_MOVE_RIGHT, "move_up": Text.UI_MOVE_UP, "move_down": Text.UI_MOVE_DOWN,
	"wait": Text.UI_WAIT_TOGGLE, "highlight": Text.UI_HIGHLIGHT, "diary": Text.UI_OPEN_CLOSE_DIARY, "reset_loop": Text.UI_RESET_LOOP,
	"cancel_action": Text.UI_CANCEL_ACTION, "interaction_one": Text.UI_INTERACTION_1, "interaction_two": Text.UI_INTERACTION_2,
	"interaction_3": Text.UI_INTERACTION_3, "interaction_4": Text.UI_INTERACTION_4, "interaction_5": Text.UI_INTERACTION_5,
	"interaction_6": Text.UI_INTERACTION_6, "interaction_7": Text.UI_INTERACTION_7, "interaction_8": Text.UI_INTERACTION_8,
	"wheel_confirm": Text.UI_CONFIRM_SELECTED_INTERACTION, "submit_code": Text.UI_SUBMIT_CODE, "clear_code": Text.UI_CLEAR_CODE,
	"continue_ending": Text.UI_CONTINUE_AFTER_ENDING, "diary_previous": Text.UI_PREVIOUS_DIARY_PAGE, "diary_next": Text.UI_NEXT_DIARY_PAGE
}
const SLOTS := ["interaction_one", "interaction_two", "interaction_3", "interaction_4", "interaction_5", "interaction_6", "interaction_7", "interaction_8"]
var defaults: Dictionary = {}
var bindings: Dictionary = {}
var capture_active := false
var release_guard := false
var last_motion: InputEventJoypadMotion
var last_motion_value := 0.0
var motion_edges: Dictionary = {}
var trigger_down: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in ACTIONS:
		defaults[action] = {"keyboard": [{}, {}], "controller": [{}, {}]}
	var keys := {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S,
		"wait": KEY_F, "highlight": KEY_H, "diary": KEY_TAB, "reset_loop": KEY_R, "cancel_action": KEY_ESCAPE,
		"submit_code": KEY_ENTER, "clear_code": KEY_BACKSPACE, "continue_ending": KEY_ENTER,
		"diary_previous": KEY_LEFT, "diary_next": KEY_RIGHT}
	for action in keys: defaults[action].keyboard[0] = {"kind": "key", "code": keys[action], "modifiers": 0}
	for index in SLOTS.size(): defaults[SLOTS[index]].keyboard[0] = {"kind": "key", "code": KEY_1 + index, "modifiers": 0}
	defaults.diary_previous.keyboard[1] = {"kind": "key", "code": KEY_PAGEUP, "modifiers": 0}
	defaults.diary_next.keyboard[1] = {"kind": "key", "code": KEY_PAGEDOWN, "modifiers": 0}
	for item in [["wait", JOY_BUTTON_B], ["highlight", JOY_BUTTON_A], ["diary", JOY_BUTTON_Y], ["cancel_action", JOY_BUTTON_B], ["wheel_confirm", JOY_BUTTON_X], ["continue_ending", JOY_BUTTON_A]]:
		defaults[item[0]].controller[0] = {"kind": "button", "code": item[1]}
	get_node("/root/Preferences").changed.connect(load_bindings)
	load_bindings()

func load_bindings() -> void:
	bindings = defaults.duplicate(true)
	var saved: Dictionary = get_node("/root/Preferences").bindings
	for action in ACTIONS:
		if not saved.get(action) is Dictionary: continue
		for device in ["keyboard", "controller"]:
			var slots: Variant = saved[action].get(device)
			if not slots is Array: continue
			for slot in mini(2, slots.size()):
				if valid(slots[slot], device): bindings[action][device][slot] = slots[slot].duplicate()
	apply()

func valid(record: Variant, device: String) -> bool:
	if not record is Dictionary: return false
	if record.is_empty(): return true
	if not record.get("code") is int: return false
	if device == "keyboard":
		if record.get("kind") != "key" or not record.get("modifiers") is int: return false
		if record.code <= 0 or OS.get_keycode_string(record.code).is_empty(): return false
		if record.modifiers & ~(KEY_MASK_SHIFT | KEY_MASK_ALT | KEY_MASK_CTRL | KEY_MASK_META): return false
	else:
		if record.get("kind") == "button":
			if record.code < 0 or record.code >= JOY_BUTTON_MAX: return false
		elif record.get("kind") == "trigger":
			if record.code not in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]: return false
		else: return false
	return reserved(record).is_empty()

func reserved(record: Dictionary) -> String:
	if record.get("kind") == "key" and record.get("code") in [KEY_SPACE, KEY_PERIOD, KEY_F8]: return Text.UI_THIS_KEY_IS_RESERVED_FOR_PAUSE_EDITOR_CONTROLS
	if record.get("kind") == "button" and record.get("code") in [JOY_BUTTON_START, JOY_BUTTON_BACK]: return Text.UI_THIS_BUTTON_IS_RESERVED_FOR_SETTINGS_OR_PAUSE_EDITOR_CONTROLS
	return ""

func to_event(record: Dictionary) -> InputEvent:
	if record.is_empty(): return null
	if record.kind == "key":
		var event := InputEventKey.new()
		event.physical_keycode = record.code
		event.shift_pressed = bool(record.modifiers & KEY_MASK_SHIFT)
		event.ctrl_pressed = bool(record.modifiers & KEY_MASK_CTRL)
		event.alt_pressed = bool(record.modifiers & KEY_MASK_ALT)
		event.meta_pressed = bool(record.modifiers & KEY_MASK_META)
		return event
	if record.kind == "button":
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = record.code
		return event
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = record.code
	event.axis_value = 1.0
	return event

func from_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey and event.physical_keycode != 0 and event.physical_keycode not in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return {"kind": "key", "code": int(event.physical_keycode), "modifiers": int(event.get_modifiers_mask())}
	if event is InputEventJoypadButton: return {"kind": "button", "code": int(event.button_index)}
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]: return {"kind": "trigger", "code": int(event.axis)}
	return {}

func apply() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, 0.5)
		InputMap.action_erase_events(action)
		for device in ["keyboard", "controller"]:
			for record in bindings[action][device]:
				var event := to_event(record)
				if event != null: InputMap.action_add_event(action, event)
		if action.begins_with("move_"):
			# Separate digital movement from the fixed sticks so trigger bindings
			# use 0.5 without changing the sticks' existing 0.2 deadzone.
			if not InputMap.has_action(action+"_stick"): InputMap.add_action(action+"_stick")
			InputMap.action_erase_events(action+"_stick")
			InputMap.action_set_deadzone(action+"_stick", 0.2)
			var axis := InputEventJoypadMotion.new()
			axis.device = -1
			axis.axis = JOY_AXIS_LEFT_X if action in ["move_left", "move_right"] else JOY_AXIS_LEFT_Y
			axis.axis_value = -1.0 if action in ["move_left", "move_up"] else 1.0
			InputMap.action_add_event(action+"_stick", axis)
	bindings_changed.emit()

func assign(action: String, device: String, slot: int, record: Dictionary) -> void:
	if not ACTIONS.has(action) or device not in ["keyboard", "controller"] or slot not in [0, 1] or not valid(record, device): return
	bindings[action][device][slot] = record.duplicate()
	commit()

func reset_device(device: String) -> void:
	for action in ACTIONS: bindings[action][device] = defaults[action][device].duplicate(true)
	commit()

func commit() -> void:
	apply()
	var prefs := get_node("/root/Preferences")
	prefs.bindings = bindings.duplicate(true)
	prefs.save_settings()

func conflicts(action: String, device: String, slot: int, record: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for other in ACTIONS:
		for index in 2:
			if other == action and index == slot: continue
			if bindings[other][device][index] == record and not result.has(ACTIONS[other]): result.append(ACTIONS[other])
	return result

func label(record: Dictionary) -> String:
	if record.is_empty(): return "Unbound"
	if record.kind == "key":
		var code: int = record.code if OS.has_feature("web") or DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(record.code)
		return OS.get_keycode_string((code if code != 0 else record.code) | record.modifiers)
	if record.kind == "trigger": return "LT" if record.code == JOY_AXIS_TRIGGER_LEFT else "RT"
	return {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_DPAD_UP: Text.UI_D_PAD_UP, JOY_BUTTON_DPAD_DOWN: Text.UI_D_PAD_DOWN, JOY_BUTTON_DPAD_LEFT: Text.UI_D_PAD_LEFT, JOY_BUTTON_DPAD_RIGHT: Text.UI_D_PAD_RIGHT}.get(record.code, Text.UI_BUTTON_D % record.code)

func prompt(action: String, controller := false) -> String:
	for record in bindings[action]["controller" if controller else "keyboard"]:
		if not record.is_empty(): return label(record)
	return "Unbound"

func blocked() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return capture_active or release_guard or focus is LineEdit or focus is TextEdit or get_viewport().get_embedded_subwindows().any(func(window): return window.visible)

func pressed(event: InputEvent, action: String) -> bool:
	if event is InputEventJoypadMotion:
		observe_motion(event)
		return not blocked() and motion_edges.get(action, false)
	return not blocked() and not event.is_echo() and event.is_action_pressed(action, false, true)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion: observe_motion(event)

func observe_motion(event: InputEventJoypadMotion) -> void:
	if event == last_motion and event.axis_value == last_motion_value: return
	last_motion = event
	last_motion_value = event.axis_value
	motion_edges = {}
	if event.axis not in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]: return
	for action in ACTIONS:
		var id := "%s:%d:%d" % [action, event.device, event.axis]
		var matches := false
		for record in bindings[action].controller:
			if record.get("kind") == "trigger" and record.code == event.axis: matches = true
		var down := matches and event.axis_value >= 0.5
		motion_edges[action] = down and not trigger_down.get(id, false)
		trigger_down[id] = down

func held(action: String) -> bool:
	return not blocked() and Input.is_action_pressed(action, true)

func movement() -> Vector2:
	if blocked(): return Vector2.ZERO
	var digital := Vector2(Input.get_action_strength("move_right", true)-Input.get_action_strength("move_left", true), Input.get_action_strength("move_down", true)-Input.get_action_strength("move_up", true))
	var stick := Input.get_vector("move_left_stick", "move_right_stick", "move_up_stick", "move_down_stick")
	return (digital+stick).limit_length()

func guard_release() -> void:
	release_guard = true

func _process(_delta: float) -> void:
	if not release_guard: return
	for action in ACTIONS:
		if Input.is_action_pressed(action): return
	if Input.is_anything_pressed(): return
	release_guard = false
