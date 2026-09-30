extends SceneTree
const PATH := "res://build/input-preferences.cfg"
var failed := false
func _initialize() -> void: call_deferred("checks")
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func key(code: int, modifiers := 0) -> Dictionary:
	return {"kind": "key", "code": code, "modifiers": modifiers}
func checks() -> void:
	var prefs = root.get_node("Preferences")
	var bindings = root.get_node("InputBindings")
	var settings = root.get_node("AudioSettings")
	prefs.settings_path = PATH
	prefs.legacy_path = "res://build/input-legacy.cfg"
	DirAccess.remove_absolute(PATH)
	var legacy := ConfigFile.new()
	legacy.set_value("audio", "Music", 27)
	legacy.set_value("controls", "stick_on_right", true)
	legacy.save(prefs.legacy_path)
	settings.load_settings()
	check(prefs.volumes.Music == 27 and prefs.stick_on_right, "Legacy values migrate")
	check(FileAccess.file_exists(PATH) and FileAccess.file_exists(prefs.legacy_path), "Migration preserves legacy file")
	bindings.assign("highlight", "keyboard", 0, key(KEY_J))
	bindings.assign("highlight", "keyboard", 1, key(KEY_K, KEY_MASK_CTRL))
	check(bindings.prompt("highlight") == "J", "Primary prompt updates")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_K
	event.pressed = true
	check(not bindings.pressed(event, "highlight"), "Modifier is required")
	event.ctrl_pressed = true
	check(bindings.pressed(event, "highlight"), "Modified alternate matches")
	event.shift_pressed = true
	check(not bindings.pressed(event, "highlight"), "Extra modifiers do not match")
	bindings.assign("highlight", "keyboard", 0, {})
	check(bindings.prompt("highlight").contains("K"), "Prompt falls back to alternate")
	bindings.assign("wait", "controller", 0, {"kind": "trigger", "code": JOY_AXIS_TRIGGER_LEFT})
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_LEFT
	trigger.device = 3
	trigger.axis_value = 0.4
	check(not bindings.pressed(trigger, "wait"), "Trigger below threshold ignored")
	trigger.axis_value = 0.8
	check(bindings.pressed(trigger, "wait"), "Trigger works on another controller")
	trigger.axis_value = 0.9
	check(not bindings.pressed(trigger, "wait"), "Held trigger does not repeat discrete actions")
	trigger.axis_value = 0.0
	bindings.observe_motion(trigger)
	trigger.axis_value = 0.8
	check(bindings.pressed(trigger, "wait"), "Released trigger can press again")
	prefs.load_settings()
	check(bindings.bindings.highlight.keyboard[0].is_empty() and bindings.bindings.highlight.keyboard[1] == key(KEY_K, KEY_MASK_CTRL), "Both slots survive reload")
	check(bindings.bindings.wait.controller[0].kind == "trigger", "Controller preference survives reload")
	check(not bindings.conflicts("wait", "keyboard", 0, key(KEY_H)).has("Highlight"), "Old binding removed")
	check(bindings.conflicts("wait", "keyboard", 0, key(KEY_R)).has("Reset loop"), "Conflicts identify action")
	bindings.reset_device("keyboard")
	check(prefs.volumes.Music == 27 and prefs.stick_on_right and bindings.bindings.wait.controller[0].kind == "trigger", "Device reset preserves other preferences")
	check(not bindings.valid(key(KEY_SPACE), "keyboard"), "Pause remains reserved")
	check(not bindings.valid({"kind":"button", "code":JOY_BUTTON_START}, "controller"), "Settings remains reserved")
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("audio", "Master", "invalid")
	config.set_value("bindings", "highlight", {"keyboard": [key(-1), key(KEY_L)], "controller": "bad"})
	config.save(PATH)
	settings.load_settings()
	check(prefs.volumes.Master == 50 and prefs.volumes.Music == 27, "Invalid audio falls back independently")
	check(bindings.bindings.highlight.keyboard[0] == key(KEY_H) and bindings.bindings.highlight.keyboard[1] == key(KEY_L), "Invalid slots fall back independently")
	settings.open_settings()
	settings.tabs.current_tab = settings.controls_tab.get_index()
	await process_frame
	var controls = settings.controls_tab
	if "--screenshots" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/controls-settings.png")
	controls.keyboard_available = false
	controls.touch_available = true
	controls.refresh_devices()
	check(not controls.sections.keyboard.visible and controls.sections.touch.visible, "Touch-only sections")
	var virtual_key := InputEventKey.new()
	virtual_key.unicode = 97
	controls.observe_device(virtual_key)
	check(not controls.keyboard_available, "Virtual text does not expose keyboard")
	controls.observe_device(event)
	check(controls.sections.keyboard.visible and controls.sections.touch.visible, "Physical keyboard reveals hybrid sections")
	check(controls.sections.controller.visible == (not Input.get_connected_joypads().is_empty()), "Controller visibility follows connection")
	controls.begin_capture("highlight", "keyboard", 0)
	controls.armed = true
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	settings.dialog.push_input(escape, true)
	check(settings.dialog.visible and controls.confirm.visible, "Escape is captured without closing Settings")
	controls.cancel_capture()
	escape.pressed = false
	settings.dialog.push_input(escape, true)
	controls.begin_capture("highlight", "keyboard", 0)
	controls._process(0.01)
	event = InputEventKey.new()
	event.physical_keycode = KEY_J
	event.keycode = KEY_J
	event.pressed = true
	settings.dialog.push_input(event, true)
	check(controls.capture.is_empty() and bindings.bindings.highlight.keyboard[0] == key(KEY_J), "Window routes captured key to binding")
	check(bindings.release_guard and not bindings.held("highlight"), "Captured input cannot leak")
	event.pressed = false
	settings.dialog.push_input(event, true)
	controls.begin_capture("highlight", "keyboard", 0)
	controls.armed = true
	event.physical_keycode = KEY_R
	event.keycode = KEY_R
	event.pressed = true
	settings.dialog.push_input(event, true)
	check(controls.confirm.visible and bindings.bindings.highlight.keyboard[0] == key(KEY_J), "Conflict waits for confirmation")
	controls._accept()
	check(bindings.bindings.highlight.keyboard[0] == key(KEY_R), "Explicit confirmation allows sharing")
	controls.begin_capture("wait", "keyboard", 0)
	controls._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(controls.capture.is_empty() and not bindings.capture_active, "Focus loss cancels capture")
	controls.begin_capture("wait", "controller", 0)
	controls._connection_changed(0, false)
	check(controls.capture.is_empty(), "Disconnect cancels controller capture")
	controls.begin_capture("wait", "keyboard", 0)
	controls._process(11.0)
	check(controls.capture.is_empty(), "Capture timeout")
	prefs.settings_path = "res://build/nonexistent-preferences-dir/settings.cfg"
	bindings.assign("highlight", "keyboard", 0, key(KEY_J))
	check(prefs.last_error != OK and settings.menu_status.visible, "Write failure is visible")
	check(bindings.bindings.highlight.keyboard[0] == key(KEY_J), "Write failure retains session binding")
	prefs.settings_path = PATH
	settings.close_settings()
	await create_timer(0.2).timeout
	check(prefs.last_error == OK, "Closing retries save")
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(prefs.legacy_path)
	print("INPUT BINDINGS %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
