extends SceneTree
const Play = preload("res://mission1/play.tscn")
const Save = preload("res://mission1/save.gd")
func _initialize() -> void: call_deferred("checks")
func key(code: int, down := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	return event
func checks() -> void:
	var prefs = root.get_node("Preferences")
	prefs.settings_path = "res://build/gameplay-bindings.cfg"
	var bindings = root.get_node("InputBindings")
	bindings.reset_device("keyboard")
	var game = Play.instantiate()
	game.save_enabled = false
	game.configure({}, false)
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_physics_process(false)
	game.controls_enabled = true
	bindings.assign("highlight", "keyboard", 0, {"kind":"key", "code":KEY_J, "modifiers":0})
	var before: bool = game.highlight
	game._unhandled_input(key(KEY_H))
	assert(game.highlight == before)
	game._unhandled_input(key(KEY_J))
	assert(game.highlight != before)
	bindings.assign("diary", "keyboard", 0, {"kind":"key", "code":KEY_K, "modifiers":0})
	game._input(key(KEY_TAB))
	assert(not game.diary_open)
	game._input(key(KEY_K))
	assert(game.diary_open)
	game._input(key(KEY_K))
	await create_timer(0.3).timeout
	assert(not game.diary_open)
	bindings.assign("move_right", "keyboard", 0, {"kind":"key", "code":KEY_L, "modifiers":0})
	Input.parse_input_event(key(KEY_L))
	Input.flush_buffered_events()
	await process_frame
	assert(game._movement_input().x > 0.9)
	var entry := LineEdit.new()
	root.add_child(entry)
	entry.grab_focus()
	assert(game._movement_input() == Vector2.ZERO)
	before = game.highlight
	game._unhandled_input(key(KEY_J))
	assert(game.highlight == before)
	Input.parse_input_event(key(KEY_L, false))
	entry.queue_free()
	await process_frame
	bindings.assign("move_right", "controller", 0, {"kind":"trigger", "code":JOY_AXIS_TRIGGER_LEFT})
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_LEFT
	trigger.axis_value = 0.3
	Input.parse_input_event(trigger)
	Input.flush_buffered_events()
	assert(game._movement_input() == Vector2.ZERO)
	trigger = trigger.duplicate()
	trigger.axis_value = 1.0
	Input.parse_input_event(trigger)
	Input.flush_buffered_events()
	assert(game._movement_input().x > 0.9)
	trigger = trigger.duplicate()
	trigger.axis_value = 0.0
	Input.parse_input_event(trigger)
	Input.flush_buffered_events()
	var expected: Dictionary = bindings.bindings.duplicate(true)
	var history: Array = game.sim.history.duplicate(true)
	var path := "res://build/gameplay-bindings.journal"
	assert(Save.new().save_run(game.sim, path).ok)
	var restored: Dictionary = Save.load_saved(path)
	assert(restored.ok and not restored.data.has("bindings") and not restored.data.has("audio"))
	assert(bindings.bindings == expected)
	assert(Save.clear(path).ok)
	assert(bindings.bindings == expected and FileAccess.file_exists(prefs.settings_path))
	assert(game.sim.history.size() >= history.size())
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(prefs.settings_path)
	print("GAMEPLAY BINDINGS PASS: actions, polling, text focus and voyage isolation")
	quit()
