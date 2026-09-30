extends Node
## Device preferences never participate in voyage serialization.
signal changed
signal accessibility_changed
signal save_failed
const DEFAULTS := {"Master": 50.0, "SFX": 100.0, "Dialogue": 100.0, "Music": 100.0}
var settings_path := "user://settings.cfg"
var legacy_path := "user://audio_settings.cfg"
var volumes := DEFAULTS.duplicate()
var stick_on_right := false
var bindings: Dictionary = {}
var language := "automatic"
var high_contrast_text_panels := false
var instant_dialogue_text := false
var last_error := OK

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	var migrate := not FileAccess.file_exists(settings_path) and (settings_path == "user://settings.cfg" or legacy_path != "user://audio_settings.cfg")
	config.load(legacy_path if migrate else settings_path)
	for bus in DEFAULTS:
		var value: Variant = config.get_value("audio", bus, DEFAULTS[bus])
		volumes[bus] = clampf(float(value), 0, 100) if (value is float or value is int) and is_finite(float(value)) else DEFAULTS[bus]
	var side: Variant = config.get_value("controls", "stick_on_right", false)
	stick_on_right = side if side is bool else false
	language = str(config.get_value("localisation", "language", "automatic"))
	for key in ["high_contrast_text_panels", "instant_dialogue_text"]:
		var value: Variant = config.get_value("accessibility", key, false)
		set(key, value if value is bool else false)
	bindings = {}
	if config.has_section("bindings"):
		for action in config.get_section_keys("bindings"):
			var value: Variant = config.get_value("bindings", action)
			if value is Dictionary: bindings[action] = value
	changed.emit()
	accessibility_changed.emit()
	if migrate and FileAccess.file_exists(legacy_path): save_settings()

func save_settings() -> Error:
	var config := ConfigFile.new()
	for bus in DEFAULTS: config.set_value("audio", bus, volumes[bus])
	config.set_value("controls", "stick_on_right", stick_on_right)
	config.set_value("localisation", "language", language)
	for key in ["high_contrast_text_panels", "instant_dialogue_text"]:
		config.set_value("accessibility", key, get(key))
	for action in bindings: config.set_value("bindings", action, bindings[action])
	last_error = config.save(settings_path)
	if last_error != OK: save_failed.emit()
	elif OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	return last_error
