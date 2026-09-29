extends Control
## Startup menu and book-to-world transition. The live Mission 1 opening is
## placed beneath the diary before the pages become a transparent window.

signal opened_to_game

const Simulation = preload("res://mission1/simulation.gd")
const RoomAudio = preload("res://mission1/room_audio.gd")
const Rooms = preload("res://mission1/rooms.gd")
const OPENING_SECONDS := 1.74
const Save = preload("res://mission1/save.gd")
const PopupSkin = preload("res://assets/ui/popup/popup_skin.gd")
const Docks = preload("res://assets/rooms/mission_1/01_docks.tscn")
const LevelLoader = preload("res://assets/ui/loading/level_loader.gd")
const LevelWait = preload("res://assets/ui/loading/level_wait.gd")
const TEST_LEVEL := "res://foundation/harness.tscn"

@export var mission_save_path := Save.DEFAULT_PATH

@onready var cover: TextureRect = $ClosedCover
@onready var lettering: TextureRect = $TitleLettering
@onready var open_book: TextureRect = $OpenBook
@onready var menu: VBoxContainer = $Menu
@onready var continue_button: Button = $Menu/ContinueButton
@onready var new_confirm: ConfirmationDialog = $NewConfirm
@onready var error_dialog: AcceptDialog = $MenuError

var _menu_audio: Node
var _preview_ms := 0.0
var _opening := false
var _game_world: Node2D
var _error_message: Label
var preview: Label
var entrance: Tween
var glint: TextureRect
var confirm_motion: Node
var error_motion: Node
var controller_menu: Node
var settings_button: Button
var level_loader: Node
var loading_diary: Control
var _waiting := false
var _pending_new := false
var _pending_saved: Dictionary = {}
var _pending_scene := LevelLoader.MISSION
var _preview_state: Dictionary = {}


func is_pause_editor_available() -> bool:
	return is_instance_valid(_game_world) and _game_world.is_pause_editor_available()


func _ready() -> void:
	level_loader = LevelLoader.new()
	add_child(level_loader)
	level_loader.prepared.connect(_level_prepared)
	level_loader.failed.connect(_level_failed)
	PopupSkin.decorate(new_confirm)
	_error_message = PopupSkin.add_message(PopupSkin.decorate(error_dialog), "")
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('github_integration_test') && new URLSearchParams(location.search).get('github_web_smoke') === 'read'")):
		call_deferred("_on_test_level")
		return
	continue_button.pressed.connect(_on_continue)
	$Menu/NewButton.pressed.connect(_on_new)
	$Menu/TestLevelButton.pressed.connect(_on_test_level)
	$Menu/QuitButton.pressed.connect(_on_quit)
	new_confirm.confirmed.connect(_start_new)
	_menu_audio = RoomAudio.new()
	add_child(_menu_audio)
	_menu_audio.set_presentation_gain(0.5)
	$WorldSlot.add_child(Docks.instantiate())
	_reset_visuals()
	_build_polish()
	_refresh_continue()
	_start_entrance()
	_signal_web_ready()
	_start_background_load.call_deferred()


var _preview_content: Dictionary = {}

func _refresh_continue() -> void:
	var loaded := Save.load_saved(mission_save_path)
	_preview_content = loaded.get("data",{}).get("authored_content",{})
	continue_button.visible = bool(loaded.ok)
	if is_instance_valid(preview):
		preview.visible = bool(loaded.ok)
		if loaded.ok:
			var state: Dictionary = loaded.data.current
			var room_name: String = _preview_content.get("rooms",Rooms.ROOMS).get(str(state.get("room","docks")),Rooms.ROOMS.docks).title
			var detail := Simulation.observation_time(int(state.get("tick",0)))
			if state.get("finished",false): room_name = "Voyage complete" if state.get("dead",[]).is_empty() else "Voyage ended"
			preview.text = "All Aboard · %s\n%s" % [detail,room_name]
	if not _opening:
		_preview_state = loaded.data.current if loaded.ok else Simulation.new().s
		if level_loader.is_prepared or _preview_state.room == "docks": _preview_destination(_preview_state)
	if continue_button.visible:
		continue_button.call_deferred("grab_focus")
	else:
		$Menu/NewButton.call_deferred("grab_focus")


func _preview_destination(state: Dictionary) -> void:
	var room_id: String = str(state.get("room","docks"))
	if not Rooms.ROOMS.has(room_id): room_id = "docks"
	var room := load("res://assets/rooms/mission_1/%s.tscn" % Rooms.ROOMS[room_id].scene).instantiate() as Node
	_preview_ms = float(state.get("tick",0))*100.0
	_menu_audio.set_room(room.get_node("RoomAudioSettings"),int(_preview_ms),0.0)
	room.free()


func _process(delta: float) -> void:
	if is_instance_valid(loading_diary): loading_diary.progress = level_loader.progress
	if _menu_audio == null or (is_instance_valid(_game_world) and _game_world.controls_enabled): return
	_preview_ms += delta*1000.0
	_menu_audio.set_game_time(int(_preview_ms))


func _on_continue() -> void:
	if _opening or _waiting or new_confirm.visible or error_dialog.visible: return
	_finish_entrance()
	var loaded: Dictionary = Save.load_saved(mission_save_path)
	if not loaded.ok:
		_refresh_continue()
		_show_error("The saved voyage could not be loaded. Its files have been kept.")
		return
	_launch_mission(loaded.data)


func _on_new() -> void:
	if _opening or _waiting or new_confirm.visible or error_dialog.visible: return
	_finish_entrance()
	if Save.has_any(mission_save_path):
		new_confirm.popup_centered()
	else:
		_start_new()


func _start_new() -> void:
	if _opening or _waiting: return
	if is_instance_valid(confirm_motion): confirm_motion.finish()
	_pending_new = true
	_launch_mission()


func _start_background_load() -> void:
	# Let the title draw before starting disk reads or the deferred web download.
	await get_tree().process_frame
	if _waiting or _opening: return
	level_loader.start(LevelLoader.MISSION,_preview_state,false,_preview_content)


func _launch_mission(saved: Dictionary = {}) -> void:
	if _opening or _waiting: return
	_pending_saved = saved
	_pending_scene = LevelLoader.MISSION
	_wait_for_level()


func _wait_for_level() -> void:
	_waiting = true
	_finish_entrance()
	var state: Dictionary = _pending_saved.get("current",Simulation.new().s)
	level_loader.start(_pending_scene,state,true,_pending_saved.get("authored_content",{}))
	if level_loader.ticket.done and str(level_loader.ticket.error).is_empty():
		_enter_prepared_level()
		return
	menu.hide()
	loading_diary = LevelWait.new()
	add_child(loading_diary)


func _level_prepared() -> void:
	if _opening: return
	if _waiting:
		_enter_prepared_level()
	else:
		_preview_destination(_preview_state)


func _level_failed(message: String) -> void:
	if not _waiting: return # A click retries a failed background download.
	_waiting = false
	_pending_new = false
	if is_instance_valid(loading_diary):
		loading_diary.queue_free()
		loading_diary = null
	menu.show()
	_show_error(message)


func _enter_prepared_level() -> void:
	if not level_loader.neighbour_ticket.is_empty(): level_loader.neighbour_ticket.cancelled = true
	# New only replaces the previous save once all required content is available.
	if _pending_new:
		var cleared: Dictionary = Save.clear(mission_save_path)
		if not cleared.ok:
			_level_failed(str(cleared.reason))
			return
	_pending_new = false
	_waiting = false
	if is_instance_valid(loading_diary):
		loading_diary.queue_free()
		loading_diary = null
	if _pending_scene == TEST_LEVEL:
		get_tree().change_scene_to_packed(level_loader.resources[TEST_LEVEL])
		return
	# Start preview before handing the same players into the opening transition.
	if _menu_audio.get_child_count() == 0:
		_preview_destination(_pending_saved.get("current",{"room":"docks","tick":0}))
	var game: Node2D = level_loader.resources[LevelLoader.MISSION].instantiate()
	game.stream_resources = true
	game.character_ticket = level_loader.character_ticket
	game.save_path = mission_save_path
	game.configure(_pending_saved, true)
	game.room_audio = _menu_audio
	game.opening_audio_fade = OPENING_SECONDS
	_menu_audio.fade_presentation_gain(1.0,OPENING_SECONDS)
	_preview_ms = float(_pending_saved.get("current",{}).get("tick",0))*100.0
	set_game_world(game)
	_game_world = game
	begin()


func _on_test_level() -> void:
	if _opening or _waiting or new_confirm.visible or error_dialog.visible: return
	_pending_scene = TEST_LEVEL
	_pending_new = false
	_wait_for_level()


func _on_quit() -> void:
	if _opening or _waiting or new_confirm.visible or error_dialog.visible: return
	_finish_entrance()
	get_tree().quit()


func _show_error(message: String) -> void:
	_error_message.text = message
	error_dialog.popup_centered()


func begin() -> void:
	if _opening:
		return
	_opening = true
	_finish_entrance()
	if is_instance_valid(preview): preview.hide()
	menu.hide()
	var tween := create_tween()
	tween.tween_method(_set_open_progress, 0.0, 1.0, 0.82).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.1)
	tween.tween_property(open_book, "scale", Vector2(2.45, 2.45), 0.82).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_method(_set_frame_alpha, 1.0, 0.0, 0.42).set_delay(0.4).set_trans(Tween.TRANS_SINE)
	await tween.finished
	cover.hide()
	lettering.hide()
	open_book.hide()
	if is_instance_valid(_game_world):
		_game_world.enable_controls()
	opened_to_game.emit()


func set_game_world(world: Node2D) -> void:
	var slot: Node2D = $WorldSlot
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()
	slot.add_child(world)


func _reset_visuals() -> void:
	_set_open_progress(0.0)
	_set_portal(1.0)
	_set_frame_alpha(1.0)
	open_book.pivot_offset = Vector2(580, 370)
	open_book.scale = Vector2.ONE
	cover.show()
	lettering.show()
	open_book.show()
	menu.show()
	_opening = false


func _set_open_progress(value: float) -> void:
	(cover.material as ShaderMaterial).set_shader_parameter("open_progress", value)
	(lettering.material as ShaderMaterial).set_shader_parameter("open_progress", value)


func _set_portal(value: float) -> void:
	(open_book.material as ShaderMaterial).set_shader_parameter("portal", value)


func _set_frame_alpha(value: float) -> void:
	(open_book.material as ShaderMaterial).set_shader_parameter("frame_alpha", value)


func _build_polish() -> void:
	preview = Label.new()
	preview.custom_minimum_size = Vector2(0,44)
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_theme_color_override("font_color",Color("f4dfb4"))
	preview.add_theme_color_override("font_outline_color",Color("17243a"))
	preview.add_theme_constant_override("outline_size",4)
	preview.add_theme_font_size_override("font_size",16)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(preview)
	menu.move_child(preview,1)
	menu.position.y = 290
	settings_button = $Menu/NewButton.duplicate(0)
	settings_button.name = "SettingsButton"
	settings_button.text = "SETTINGS"
	# Duplicate appearance only; do not inherit the New action or feedback metadata.
	for key in settings_button.get_meta_list(): settings_button.remove_meta(key)
	menu.add_child(settings_button)
	menu.move_child(settings_button,3)
	settings_button.pressed.connect(_on_settings)
	glint = TextureRect.new()
	glint.texture = lettering.texture
	glint.size = lettering.size
	glint.position = lettering.position
	glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glint.material = ShaderMaterial.new()
	glint.material.shader = preload("res://assets/ui/mission_1/title_glint.gdshader")
	add_child(glint)
	confirm_motion = preload("res://assets/ui/popup/popup_motion.gd").new()
	confirm_motion.setup(new_confirm,self)
	error_motion = preload("res://assets/ui/popup/popup_motion.gd").new()
	error_motion.setup(error_dialog,self)
	new_confirm.exclusive = true
	error_dialog.exclusive = true
	new_confirm.canceled.connect(func(): confirm_motion.leave(func(): confirm_motion.restore_focus($Menu/NewButton)))
	error_dialog.dialog_hide_on_ok = false
	error_dialog.confirmed.connect(func(): error_motion.leave(func(): error_motion.restore_focus(continue_button if continue_button.visible else $Menu/NewButton)))
	error_dialog.canceled.connect(func(): error_motion.leave(func(): error_motion.restore_focus($Menu/NewButton)))
	controller_menu = _controller_for(self,func(): return menu.get_children(),func(): return menu.visible and not _opening and not _waiting and not get_tree().paused and not new_confirm.visible and not error_dialog.visible,func(): pass)
	_controller_for(new_confirm,func(): return [new_confirm.get_cancel_button(),new_confirm.get_ok_button()],func(): return new_confirm.visible and not confirm_motion.closing,func(): new_confirm.canceled.emit())
	_controller_for(error_dialog,func(): return [error_dialog.get_ok_button()],func(): return error_dialog.visible and not error_motion.closing,func(): error_dialog.canceled.emit())
	new_confirm.about_to_popup.connect(func(): new_confirm.get_cancel_button().call_deferred("grab_focus"))

func _start_entrance() -> void:
	menu.modulate.a = 0.0
	lettering.modulate.a = 0.0
	preview.modulate.a = 0.0
	entrance = create_tween()
	entrance.tween_property(menu,"modulate:a",1.0,0.25)
	entrance.parallel().tween_property(lettering,"modulate:a",1.0,0.25)
	entrance.parallel().tween_property(preview,"modulate:a",1.0,0.25)
	entrance.tween_method(func(value: float): glint.material.set_shader_parameter("sweep",value),-0.1,1.2,0.7)
	entrance.tween_callback(glint.hide)

func _finish_entrance() -> void:
	if entrance: entrance.kill()
	menu.modulate.a = 1.0
	lettering.modulate.a = 1.0
	if is_instance_valid(preview): preview.modulate.a = 1.0
	if is_instance_valid(glint): glint.hide()

func _signal_web_ready() -> void:
	if not OS.has_feature("web"): return
	await RenderingServer.frame_post_draw
	JavaScriptBridge.eval("window.diaryTitleReady = true; window.dispatchEvent(new Event('diary-title-ready'));",true)


func _on_settings() -> void:
	if _opening or _waiting or new_confirm.visible or error_dialog.visible: return
	_finish_entrance()
	get_node("/root/AudioSettings").open_settings()

func _controller_for(parent: Node, controls: Callable, active: Callable, on_back: Callable) -> Node:
	var navigator := preload("res://foundation/controller_menu.gd").new()
	navigator.available = func():
		var buttons: Array = []
		for item in controls.call():
			if item is BaseButton: buttons.append(item)
		return buttons
	navigator.enabled = active
	navigator.back = on_back
	parent.add_child(navigator)
	return navigator

func get_pause_editor_scene() -> Node:
	return _game_world if is_instance_valid(_game_world) and _game_world.has_method("toggle_pause_editor") else self
