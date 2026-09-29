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
const MissionOpening = preload("res://mission1/play.tscn")
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


func is_pause_editor_available() -> bool:
	return is_instance_valid(_game_world) and _game_world.controls_enabled


func _ready() -> void:
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
	_reset_visuals()
	_refresh_continue()


func _refresh_continue() -> void:
	var loaded := Save.load_saved(mission_save_path)
	continue_button.visible = bool(loaded.ok)
	if not _opening:
		_preview_destination(loaded.data.current if loaded.ok else Simulation.new().s)
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
	if _menu_audio == null or (is_instance_valid(_game_world) and _game_world.controls_enabled): return
	_preview_ms += delta*1000.0
	_menu_audio.set_game_time(int(_preview_ms))


func _on_continue() -> void:
	var loaded: Dictionary = Save.load_saved(mission_save_path)
	if not loaded.ok:
		_refresh_continue()
		_show_error("The saved voyage could not be loaded. Its files have been kept.")
		return
	_launch_mission(loaded.data)


func _on_new() -> void:
	if _opening: return
	if Save.has_any(mission_save_path):
		new_confirm.popup_centered()
	else:
		_start_new()


func _start_new() -> void:
	if _opening: return
	var cleared: Dictionary = Save.clear(mission_save_path)
	if not cleared.ok:
		_show_error(str(cleared.reason))
		return
	_launch_mission()


func _launch_mission(saved: Dictionary = {}) -> void:
	if _opening: return
	var game: Node2D = MissionOpening.instantiate()
	game.save_path = mission_save_path
	game.configure(saved, true)
	game.room_audio = _menu_audio
	game.opening_audio_fade = OPENING_SECONDS
	_menu_audio.fade_presentation_gain(1.0,OPENING_SECONDS)
	_preview_ms = float(saved.get("current",{}).get("tick",0))*100.0
	set_game_world(game)
	_game_world = game
	begin()


func _on_test_level() -> void:
	get_tree().change_scene_to_file(TEST_LEVEL)


func _on_quit() -> void:
	get_tree().quit()


func _show_error(message: String) -> void:
	_error_message.text = message
	error_dialog.popup_centered()


func begin() -> void:
	if _opening:
		return
	_opening = true
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
