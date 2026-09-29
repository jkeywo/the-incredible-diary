extends Node2D
## Controllable Mission 1 dock opening. The authored rescue simulation is still
## to be assembled; this scene establishes the title-to-world handoff.

const Save = preload("res://mission1/opening_save.gd")
const RoomAudio = preload("res://mission1/room_audio.gd")
const DOCKS = preload("res://assets/rooms/mission_1/01_docks.tscn")
const FOYER = preload("res://assets/rooms/mission_1/02_foyer.tscn")
const WALK_SPEED := 140.0
const OPENING_ROOM_FADE_SECONDS := 1.74

@export var save_path := Save.DEFAULT_PATH

@onready var room_slot: Node2D = $RoomSlot
@onready var amelia: AnimatedSprite2D = $Amelia
@onready var room_audio: RoomAudio = $RoomAudio

var controls_enabled := false
var room_id := "docks"
var player_position := Vector2(580, 490)
var facing := "down"
var elapsed_ms := 0
var history: Array[Dictionary] = []
var _initial_state: Dictionary = {}
var _save_enabled := false
var _record_elapsed := 0.0
var _save_elapsed := 0.0
var _elapsed_fraction_ms := 0.0
var _first_room := true


func configure(saved: Dictionary = {}, enable_save: bool = true) -> void:
	_initial_state = saved.duplicate(true)
	_save_enabled = enable_save


func _ready() -> void:
	if not _initial_state.is_empty():
		room_id = str(_initial_state.room)
		player_position = Vector2(float(_initial_state.position[0]), float(_initial_state.position[1]))
		facing = str(_initial_state.facing)
		elapsed_ms = int(_initial_state.elapsed_ms)
		for entry in _initial_state.history:
			history.append(entry.duplicate(true))
	_show_room()
	amelia.position = player_position
	amelia.play_action("idle", facing)
	if history.is_empty():
		_record_snapshot()
	if _save_enabled and _initial_state.is_empty():
		_persist()
	set_physics_process(false)


func enable_controls() -> void:
	controls_enabled = true
	set_physics_process(true)


func _unhandled_input(event: InputEvent) -> void:
	if controls_enabled and event.is_action_pressed("pause_game"):
		get_tree().paused = not get_tree().paused
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not controls_enabled or get_tree().paused:
		return
	var advance_ms := delta * 1000.0 + _elapsed_fraction_ms
	var whole_ms := floori(advance_ms)
	elapsed_ms += whole_ms
	_elapsed_fraction_ms = advance_ms - whole_ms
	room_audio.set_game_time(elapsed_ms)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length_squared() > 0.01:
		var step := direction * WALK_SPEED * delta
		var candidate := player_position + step
		if _can_stand(candidate):
			player_position = candidate
		else:
			candidate = player_position + Vector2(step.x, 0)
			if _can_stand(candidate):
				player_position = candidate
			candidate = player_position + Vector2(0, step.y)
			if _can_stand(candidate):
				player_position = candidate
		facing = _direction_name(direction)
		amelia.position = player_position
		amelia.play_action("walk", facing)
	else:
		amelia.play_action("idle", facing)
	if room_id == "docks" and player_position.y <= 104.0:
		_change_room("foyer", Vector2(580, 630))
	elif room_id == "foyer" and player_position.y >= 674.0 and absf(player_position.x - 580.0) < 75.0:
		_change_room("docks", Vector2(580, 150))
	_record_elapsed += delta
	_save_elapsed += delta
	if _record_elapsed >= 0.1:
		_record_elapsed = 0.0
		_record_snapshot()
	if _save_enabled and _save_elapsed >= 1.0:
		_save_elapsed = 0.0
		_persist()


func _can_stand(point: Vector2) -> bool:
	if room_id == "docks":
		return (point.x >= 170 and point.x <= 990 and point.y >= 235 and point.y <= 675) or \
			(point.x >= 525 and point.x <= 635 and point.y >= 90 and point.y <= 250)
	return point.x >= 155 and point.x <= 1005 and point.y >= 100 and point.y <= 690


func _direction_name(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0 else "left"
	return "down" if direction.y > 0 else "up"


func _change_room(next_room: String, arrival: Vector2) -> void:
	room_id = next_room
	player_position = arrival
	amelia.position = arrival
	_show_room()
	_record_snapshot()
	if _save_enabled:
		_persist()


func _show_room() -> void:
	for child in room_slot.get_children():
		room_slot.remove_child(child)
		child.queue_free()
	var packed: PackedScene = DOCKS if room_id == "docks" else FOYER
	var room := packed.instantiate()
	room_slot.add_child(room)
	var opening_fade := OPENING_ROOM_FADE_SECONDS if _first_room else -1.0
	room_audio.set_room(room.get_node("RoomAudioSettings"), elapsed_ms, opening_fade)
	_first_room = false


func _record_snapshot() -> void:
	var snapshot := {
		"t_ms": elapsed_ms,
		"room": room_id,
		"x": player_position.x,
		"y": player_position.y,
		"facing": facing,
	}
	if not history.is_empty() and int(history[-1].t_ms) == elapsed_ms:
		history[-1] = snapshot
	else:
		history.append(snapshot)


func _persist() -> void:
	_record_snapshot()
	var data := {
		"schema": Save.SCHEMA,
		"room": room_id,
		"position": [player_position.x, player_position.y],
		"facing": facing,
		"elapsed_ms": elapsed_ms,
		"history": history,
	}
	var result: Dictionary = Save.write(data, save_path)
	if not result.ok:
		push_warning(str(result.reason))


func _exit_tree() -> void:
	if _save_enabled and controls_enabled and not history.is_empty():
		_persist()
	get_tree().paused = false
