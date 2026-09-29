extends CanvasLayer
const PopupSkin = preload("res://assets/ui/popup/popup_skin.gd")
## Global player preferences, separate from voyage saves and authored room levels.
## Future voice players should use the Dialogue bus.

const MAIN_MENU := "res://assets/ui/mission_1/title_screen.tscn"
const DEFAULTS := {"Master": 50.0, "SFX": 100.0, "Dialogue": 100.0, "Music": 100.0}
var settings_path := "user://audio_settings.cfg"
var volumes: Dictionary = DEFAULTS.duplicate()
var sliders: Dictionary = {}
var toggle: Button
var main_menu_button: Button
var menu_status: Label
var dialog: AcceptDialog
var _was_paused := false
var _opened := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	load_settings()
	_build_ui()
	get_tree().scene_changed.connect(close_settings)


func load_settings() -> void:
	var config := ConfigFile.new()
	config.load(settings_path)
	for bus in DEFAULTS:
		var value: Variant = config.get_value("audio", bus, DEFAULTS[bus])
		if not (value is float or value is int) or not is_finite(float(value)):
			value = DEFAULTS[bus]
		set_volume(bus, float(value))


func set_volume(bus: String, percent: float) -> void:
	if not DEFAULTS.has(bus) or not is_finite(percent):
		return
	volumes[bus] = clampf(percent, 0.0, 100.0)
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus] / 100.0, 0.0001)))
	AudioServer.set_bus_mute(index, volumes[bus] == 0.0)


func save_settings() -> void:
	var config := ConfigFile.new()
	for bus in DEFAULTS:
		config.set_value("audio", bus, volumes[bus])
	if config.save(settings_path) != OK:
		push_warning("Could not save audio preferences.")


func open_settings() -> void:
	if _opened:
		return
	_was_paused = get_tree().paused
	_opened = true
	get_tree().paused = true
	for bus in sliders:
		sliders[bus].value = volumes[bus]
	menu_status.hide()
	var scene := get_tree().current_scene
	main_menu_button.disabled = scene == null or (scene.scene_file_path == MAIN_MENU and not is_instance_valid(scene.get("_game_world")))
	dialog.popup_centered(Vector2i(440, 390))
	sliders["Master"].grab_focus()


func close_settings() -> void:
	if not _opened:
		return
	_opened = false
	dialog.hide()
	get_tree().paused = _was_paused
	save_settings()
	toggle.grab_focus()


func _save_before_leaving(node: Node) -> bool:
	if node.has_method("save_before_leaving"):
		return bool(node.save_before_leaving())
	for child in node.get_children():
		if not _save_before_leaving(child): return false
	return true


func return_to_main_menu() -> void:
	var scene := get_tree().current_scene
	if scene == null: return
	if not _save_before_leaving(scene):
		menu_status.text = "The game could not be saved. You are still in the current game; try again."
		menu_status.show()
		return
	var result := get_tree().change_scene_to_file(MAIN_MENU)
	if result != OK:
		menu_status.text = "The main menu could not be opened. Please try again."
		menu_status.show()
		return
	# Returning from Settings or the paused editor must leave the menu running.
	_was_paused = false
	close_settings()
	get_tree().paused = false


func _build_ui() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	toggle = Button.new()
	toggle.position = Vector2(8, 8)
	toggle.size = Vector2(40, 40)
	toggle.tooltip_text = "Settings"
	toggle.draw.connect(_draw_cog)
	toggle.pressed.connect(open_settings)
	overlay.add_child(toggle)
	dialog = AcceptDialog.new()
	dialog.title = "Settings"
	dialog.ok_button_text = "Close"
	dialog.exclusive = true
	dialog.confirmed.connect(close_settings)
	dialog.canceled.connect(close_settings)
	add_child(dialog)
	var content := PopupSkin.decorate(dialog)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(400, 240)
	content.add_child(tabs)
	var audio := VBoxContainer.new()
	audio.name = "Audio"
	audio.add_theme_constant_override("separation", 16)
	tabs.add_child(audio)
	for bus in DEFAULTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		audio.add_child(row)
		var label := Label.new()
		label.text = "Master volume" if bus == "Master" else bus
		label.custom_minimum_size.x = 140
		row.add_child(label)
		var slider := HSlider.new()
		slider.max_value = 100
		slider.step = 1
		slider.value = volumes[bus]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 160
		slider.tooltip_text = label.text
		row.add_child(slider)
		var amount := Label.new()
		amount.custom_minimum_size.x = 48
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.text = "%d%%" % volumes[bus]
		row.add_child(amount)
		slider.value_changed.connect(func(value: float):
			set_volume(bus, value)
			amount.text = "%d%%" % value
			save_settings())
		sliders[bus] = slider
	main_menu_button = Button.new()
	main_menu_button.text = "Return to main menu"
	main_menu_button.pressed.connect(return_to_main_menu)
	content.add_child(main_menu_button)
	menu_status = Label.new()
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_status.custom_minimum_size.x = 400
	menu_status.hide()
	content.add_child(menu_status)


func _draw_cog() -> void:
	var center := toggle.size / 2.0
	var color := Color("f1d49a")
	toggle.draw_arc(center, 9, 0, TAU, 32, color, 4, true)
	for tooth in range(8):
		var direction := Vector2.from_angle(tooth * TAU / 8.0)
		toggle.draw_line(center + direction * 9, center + direction * 14, color, 5, true)
