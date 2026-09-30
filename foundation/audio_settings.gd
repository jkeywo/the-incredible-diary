extends CanvasLayer
signal controls_changed
const TouchControls = preload("res://assets/ui/mission_1/touch_controls.gd")
const PopupSkin = preload("res://assets/ui/popup/popup_skin.gd")
## Global player preferences, separate from voyage saves and authored room levels.
## Future voice players should use the Dialogue bus.

const MAIN_MENU := "res://assets/ui/mission_1/title_screen.tscn"
const DEFAULTS := {"Master": 50.0, "SFX": 100.0, "Dialogue": 100.0, "Music": 100.0}
var settings_path: String:
	get: return get_node("/root/Preferences").settings_path
	set(value): get_node("/root/Preferences").settings_path = value
var volumes: Dictionary = DEFAULTS.duplicate()
var sliders: Dictionary = {}
var toggle: Button
var main_menu_button: Button
var menu_status: Label
var dialog: AcceptDialog
var _was_paused := false
var _opened := false
var motion: Node
var _closing := false
var stick_on_right := false
var touch_available := false
var tabs: TabContainer
var controls_tab: VBoxContainer
var stick_side: OptionButton
var controller_menu: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	load_settings()
	touch_available = TouchControls.supported()
	_build_ui()
	get_tree().scene_changed.connect(_finish_close)
	get_node("/root/Preferences").save_failed.connect(_show_save_error)


func load_settings() -> void:
	var prefs := get_node("/root/Preferences")
	prefs.load_settings()
	for bus in DEFAULTS: set_volume(bus, prefs.volumes[bus])
	set_stick_on_right(prefs.stick_on_right)


func set_stick_on_right(value: bool) -> void:
	stick_on_right = value
	get_node("/root/Preferences").stick_on_right = value
	controls_changed.emit()


func _input(event: InputEvent) -> void:
	if controls_tab != null: controls_tab.observe_device(event)
	if get_node("/root/InputBindings").capture_active: return
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START:
		get_viewport().set_input_as_handled()
		if event.pressed:
			if _opened: close_settings()
			elif get_viewport().get_embedded_subwindows().all(func(window): return not window.visible): open_settings()
		return
	if event is InputEventScreenTouch and not touch_available:
		touch_available = true
		_refresh_controls_tab()


func _refresh_controls_tab() -> void:
	controls_tab.touch_available = touch_available or controls_tab.touch_available
	controls_tab.refresh_devices()
	stick_side.select(1 if stick_on_right else 0)


func set_volume(bus: String, percent: float) -> void:
	if not DEFAULTS.has(bus) or not is_finite(percent):
		return
	volumes[bus] = clampf(percent, 0.0, 100.0)
	get_node("/root/Preferences").volumes[bus] = volumes[bus]
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus] / 100.0, 0.0001)))
	AudioServer.set_bus_mute(index, volumes[bus] == 0.0)


func save_settings() -> void:
	get_node("/root/Preferences").save_settings()

func _show_save_error() -> void:
	menu_status.text = "Preferences could not be saved. Changes work for this session; closing Settings retries."
	menu_status.show()


func open_settings() -> void:
	if _opened or _closing:
		return
	_was_paused = get_tree().paused
	_opened = true
	get_tree().paused = true
	for bus in sliders:
		sliders[bus].value = volumes[bus]
	touch_available = touch_available or TouchControls.supported()
	_refresh_controls_tab()
	menu_status.visible = get_node("/root/Preferences").last_error != OK
	var scene := get_tree().current_scene
	main_menu_button.disabled = scene == null or (scene.scene_file_path == MAIN_MENU and not is_instance_valid(scene.get("_game_world")))
	dialog.popup_centered(Vector2i(440, 390))
	_focus_tab()


func close_settings() -> void:
	if get_node("/root/InputBindings").capture_active: return
	if not _opened:
		return
	if _closing: return
	_closing = true
	motion.leave(_finish_close)


func _finish_close() -> void:
	if not _opened and not _closing: return
	_opened = false
	_closing = false
	motion.finish()
	get_node("/root/InputBindings").guard_release()
	get_tree().paused = _was_paused
	save_settings()
	motion.restore_focus(toggle)


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
	_finish_close()
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
	dialog.dialog_hide_on_ok = false
	dialog.confirmed.connect(close_settings)
	dialog.canceled.connect(close_settings)
	add_child(dialog)
	var content := PopupSkin.decorate(dialog)
	motion = preload("res://assets/ui/popup/popup_motion.gd").new()
	motion.setup(dialog,overlay)
	tabs = TabContainer.new()
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
	controls_tab = preload("res://foundation/controls_settings.gd").new()
	controls_tab.name = "Controls"
	tabs.add_child(controls_tab)
	stick_side = controls_tab.stick_side
	_refresh_controls_tab()
	main_menu_button = Button.new()
	main_menu_button.text = "Return to main menu"
	main_menu_button.pressed.connect(return_to_main_menu)
	content.add_child(main_menu_button)
	menu_status = Label.new()
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_status.custom_minimum_size.x = 400
	menu_status.hide()
	content.add_child(menu_status)
	controller_menu = preload("res://foundation/controller_menu.gd").new()
	controller_menu.available = _controller_choices
	controller_menu.enabled = func(): return _opened and not _closing and dialog.visible and not get_node("/root/InputBindings").capture_active
	controller_menu.start_is_back = true
	controller_menu.back = close_settings
	controller_menu.change_tab = _controller_tab
	dialog.add_child(controller_menu)
	tabs.tab_changed.connect(func(_index): _focus_tab())


func _draw_cog() -> void:
	var center := toggle.size / 2.0
	var color := Color("f1d49a")
	toggle.draw_arc(center, 9, 0, TAU, 32, color, 4, true)
	for tooth in range(8):
		var direction := Vector2.from_angle(tooth * TAU / 8.0)
		toggle.draw_line(center + direction * 9, center + direction * 14, color, 5, true)


func _controller_choices() -> Array:
	var controls: Array = sliders.values() if tabs.current_tab == 0 else controls_tab.choices()
	return controls + [main_menu_button,dialog.get_ok_button()]

func _focus_tab() -> void:
	if not _opened: return
	var choices := _controller_choices()
	for control in choices:
		if control.is_visible_in_tree():
			control.grab_focus()
			break

func _controller_tab(step: int) -> void:
	for offset in range(1,tabs.get_tab_count()+1):
		var index := posmod(tabs.current_tab+step*offset,tabs.get_tab_count())
		if tabs.is_tab_hidden(index) or tabs.is_tab_disabled(index): continue
		tabs.current_tab = index
		_focus_tab()
		return
