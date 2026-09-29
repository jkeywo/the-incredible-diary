extends Node2D
## Standalone room/audio audition: room beds and Mission 1 event cues.

const RoomAudio = preload("res://mission1/room_audio.gd")
const GEORGE_STREET = preload("res://assets/audio/mission_1/music/george_street_shuffle.mp3")
const ROOMS: Array[PackedScene] = [
	preload("res://assets/rooms/mission_1/01_docks.tscn"),
	preload("res://assets/rooms/mission_1/02_foyer.tscn"),
	preload("res://assets/rooms/mission_1/03_cabin_corridor.tscn"),
	preload("res://assets/rooms/mission_1/04_controls_and_steam.tscn"),
	preload("res://assets/rooms/mission_1/05_party_salon.tscn"),
]
const NAMES := ["Docks", "Foyer", "Cabins and corridor", "Controls and steam", "Party salon"]
const CUE_NAMES: Array[StringName] = [
	&"footstep_dock", &"footstep_wood", &"baggage_rustle", &"baggage_move",
	&"baggage_set_down", &"cabin_door_open", &"cabin_door_close",
	&"service_door_open", &"service_door_close", &"control_button",
	&"control_switch", &"steam_valve", &"steam_hiss", &"chandelier_creak",
	&"chandelier_impact", &"chandelier_glass", &"shove", &"drink_spill",
	&"steam_cough", &"crew_alarm",
]

@export_range(0, 4) var starting_room := 0

@onready var room_slot: Node2D = $RoomSlot
@onready var audio: RoomAudio = $RoomAudio
@onready var event_audio: Node = $EventAudio
@onready var help_label: Label = $CanvasLayer/HelpLabel

var elapsed_ms := 0
var _elapsed_fraction_ms := 0.0
var room_index := 0
var use_george_street := false
var cue_index := 0


func _ready() -> void:
	_show_room(starting_room)


func _process(delta: float) -> void:
	if not get_tree().paused:
		var advance_ms := delta * 1000.0 + _elapsed_fraction_ms
		var whole_ms := floori(advance_ms)
		elapsed_ms += whole_ms
		_elapsed_fraction_ms = advance_ms - whole_ms
		audio.set_game_time(elapsed_ms)
	_update_label()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if get_tree().paused:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_5:
		_show_room(event.keycode - KEY_1)
	elif event.keycode == KEY_G:
		use_george_street = not use_george_street
		if room_index == 4:
			_show_room(4)
	elif event.keycode == KEY_Q:
		cue_index = posmod(cue_index - 1, CUE_NAMES.size())
	elif event.keycode == KEY_F:
		cue_index = (cue_index + 1) % CUE_NAMES.size()
	elif event.keycode == KEY_E:
		event_audio.call("play_cue", CUE_NAMES[cue_index])
	else:
		return
	get_viewport().set_input_as_handled()


func _show_room(index: int) -> void:
	room_index = index
	for child in room_slot.get_children():
		room_slot.remove_child(child)
		child.queue_free()
	var room := ROOMS[index].instantiate()
	room_slot.add_child(room)
	var settings: Node = room.get_node("RoomAudioSettings")
	if index == 4 and use_george_street:
		settings.set("music", GEORGE_STREET)
	audio.set_room(settings, elapsed_ms)
	_update_label()


func _update_label() -> void:
	var track := "George Street Shuffle" if use_george_street else "Hot Swing"
	help_label.text = "%s  |  %.1fs  |  %s\n1-5 rooms   G salon track (%s)   Space pause\nQ/F select cue (%s)   E play" % [
		NAMES[room_index], float(elapsed_ms) / 1000.0,
		"PAUSED" if get_tree().paused else "PLAYING", track,
		CUE_NAMES[cue_index],
	]


func _exit_tree() -> void:
	get_tree().paused = false
