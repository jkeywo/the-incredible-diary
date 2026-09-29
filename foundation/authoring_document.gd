extends RefCounted
class_name FoundationAuthoringDocument

signal changed

const ProjectAssets = preload("res://foundation/project_assets.gd")
const Content = preload("res://foundation/content.gd")
const Dialogue = preload("res://foundation/dialogue.gd")

# The document owns edits. A rejected draft never replaces applied simulation content.
var content: Dictionary
var applied_content: Dictionary
var source_draft: String
var scenario_draft: String
var scenario_error := ""
var scene_drafts: Dictionary = {}
var scene_errors: Dictionary = {}
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var baseline_head := "local"
var remote_origin: Dictionary = {}
var conflict_handoff: Dictionary = {}
var pending_conflict_local: Dictionary = {}
var recovery_conflict := false
var revision := 0
var source_group_open := false
var scenario_group_open := false
var scene_group_open := ""

func _init(initial_content: Dictionary) -> void:
	content = initial_content.duplicate(true)
	applied_content = initial_content.duplicate(true)
	source_draft = str(content.get("dialogue", ""))
	scenario_draft = JSON.stringify(content, "\t")
	_sync_scene_drafts()

func set_source(source: String, label: String = "Edit scene source") -> void:
	if source == source_draft:
		return
	finish_scenario_group()
	finish_scene_group()
	if not source_group_open:
		_record(label, _snapshot())
	source_group_open = true
	source_draft = source
	_changed()

func finish_source_group() -> void:
	source_group_open = false

func set_scenario_source(source: String) -> void:
	if source == scenario_draft:
		return
	finish_source_group()
	finish_scene_group()
	if not scenario_group_open:
		_record("Edit scenario source", _snapshot())
	scenario_group_open = true
	scenario_draft = source
	var parser := JSON.new()
	if parser.parse(source) != OK or not parser.data is Dictionary:
		scenario_error = "Scenario source is not a JSON object: " + parser.get_error_message()
	else:
		var errors := Content.validate(parser.data)
		if not errors.is_empty():
			scenario_error = "; ".join(errors)
		else:
			var source_was_unmodified := source_draft == str(content.get("dialogue", ""))
			content = parser.data.duplicate(true)
			pending_conflict_local.clear()
			scene_errors.clear()
			scene_drafts = content.get("scenes", {}).duplicate(true)
			_sync_scene_drafts()
			if source_was_unmodified:
				source_draft = str(content.dialogue)
			scenario_error = ""
	_changed()

func finish_scenario_group() -> void:
	scenario_group_open = false

func set_scene_source(scene_id: String, source: String) -> void:
	if scene_id.is_empty() or scene_drafts.get(scene_id, "") == source:
		return
	finish_source_group()
	finish_scenario_group()
	if scene_group_open != scene_id:
		_record("Edit scene %s" % scene_id, _snapshot())
	scene_group_open = scene_id
	scene_drafts[scene_id] = source
	var actor_ids: Array[String] = []
	for actor in content.actors:
		actor_ids.append(str(actor.id))
	var errors: Array[String] = Dialogue.parse(source, actor_ids).errors
	if errors.is_empty():
		var next_scenes: Dictionary = content.get("scenes", {}).duplicate(true)
		next_scenes[scene_id] = source
		content.scenes = next_scenes
		scene_errors.erase(scene_id)
		if scenario_error.is_empty():
			scenario_draft = JSON.stringify(content, "\t")
	else:
		scene_errors[scene_id] = "; ".join(errors)
	_changed()

func finish_scene_group() -> void:
	scene_group_open = ""

func _sync_scene_drafts() -> void:
	for scene_id in content.get("scenes", {}):
		if not scene_errors.has(scene_id):
			scene_drafts[scene_id] = str(content.scenes[scene_id])

func replace_content(next_content: Dictionary, label: String) -> void:
	if next_content == content:
		return
	finish_source_group()
	finish_scenario_group()
	finish_scene_group()
	_record(label, _snapshot())
	var source_was_unmodified := source_draft == str(content.get("dialogue", ""))
	content = next_content.duplicate(true)
	if source_was_unmodified:
		source_draft = str(content.get("dialogue", ""))
	if scenario_error.is_empty():
		scenario_draft = JSON.stringify(content, "\t")
	_sync_scene_drafts()
	_changed()

func stage_invalid_merge(merged_candidate: Dictionary, errors: Array, valid_local: Dictionary) -> void:
	finish_source_group()
	finish_scenario_group()
	finish_scene_group()
	_record("Inspect invalid integrated project", _snapshot())
	scenario_draft = JSON.stringify(merged_candidate, "\t")
	pending_conflict_local = valid_local.duplicate(true)
	var messages := PackedStringArray()
	for error in errors:
		messages.append(str(error))
	scenario_error = "; ".join(messages)
	_changed()

func undo() -> String:
	if undo_stack.is_empty():
		return ""
	finish_source_group()
	finish_scenario_group()
	finish_scene_group()
	var operation: Dictionary = undo_stack.pop_back()
	redo_stack.append({"label": operation.label, "state": _snapshot()})
	_restore(operation.state)
	_changed()
	return str(operation.label)

func redo() -> String:
	if redo_stack.is_empty():
		return ""
	finish_source_group()
	finish_scenario_group()
	finish_scene_group()
	var operation: Dictionary = redo_stack.pop_back()
	undo_stack.append({"label": operation.label, "state": _snapshot()})
	_restore(operation.state)
	_changed()
	return str(operation.label)

func candidate() -> Dictionary:
	var result := content.duplicate(true)
	result.dialogue = source_draft
	var payload := result.duplicate(true)
	payload.erase("version")
	var applied_payload := applied_content.duplicate(true)
	applied_payload.erase("version")
	if payload != applied_payload:
		result.version = "edit-" + JSON.stringify(payload).sha256_text().substr(0, 16)
	else:
		result.version = applied_content.version
	return result

func validate() -> Array[String]:
	if not scenario_error.is_empty():
		return [scenario_error]
	if not scene_errors.is_empty():
		var draft_errors: Array[String] = []
		for scene_id in scene_errors:
			draft_errors.append("Scene %s: %s" % [scene_id, scene_errors[scene_id]])
		return draft_errors
	return Content.validate(candidate())

func apply_to(simulation: FoundationRun, from_tick: int = -1) -> Dictionary:
	if recovery_conflict:
		return {"ok": false, "reason": "Recovered draft differs from the saved run; review it and choose Allow recovered draft before continuing", "restart": false}
	finish_source_group()
	finish_scenario_group()
	finish_scene_group()
	var proposed := candidate()
	var errors := validate()
	if not errors.is_empty():
		return {"ok": false, "reason": "; ".join(errors), "restart": false}
	var result: Dictionary = simulation.continue_with_content(proposed, from_tick)
	if result.ok:
		var applied_changed := content != proposed or applied_content != proposed
		content = proposed.duplicate(true)
		applied_content = proposed.duplicate(true)
		if scenario_error.is_empty():
			scenario_draft = JSON.stringify(content, "\t")
		_sync_scene_drafts()
		if applied_changed:
			_changed()
	return result

func change_head(next_head: String) -> void:
	if next_head == baseline_head:
		return
	finish_source_group()
	finish_scenario_group()
	finish_scene_group()
	baseline_head = next_head
	conflict_handoff.clear()
	pending_conflict_local.clear()
	undo_stack.clear()
	redo_stack.clear()
	_changed()

func has_protected_work() -> bool:
	return content != applied_content or source_draft != str(content.get("dialogue", "")) or not scenario_error.is_empty() or not scene_errors.is_empty() or not undo_stack.is_empty() or not redo_stack.is_empty()

func snapshot_for_remote_update() -> Dictionary:
	return _snapshot()

func checkout_remote(repository: String, branch: String, head: String, baseline_content: Dictionary, later_edit_state: Dictionary = {}) -> void:
	var changed_origin: bool = remote_origin.get("repository", "") != repository or remote_origin.get("branch", "") != branch
	if changed_origin and head == baseline_head:
		baseline_head = "local"
	change_head(head)
	remote_origin = {"repository": repository, "branch": branch, "head": head, "content": baseline_content.duplicate(true)}
	if not later_edit_state.is_empty():
		undo_stack.append({"label": "Edit during GitHub commit", "state": later_edit_state.duplicate(true)})
	_changed()

func record_conflict_handoff(details: Dictionary) -> void:
	conflict_handoff = details.duplicate(true)
	_changed()

func reconcile_runtime(runtime_content: Dictionary) -> bool:
	if applied_content == runtime_content:
		return false
	finish_source_group()
	finish_scenario_group()
	finish_scene_group()
	undo_stack.clear()
	redo_stack.clear()
	applied_content = runtime_content.duplicate(true)
	recovery_conflict = content != runtime_content or source_draft != str(runtime_content.get("dialogue", ""))
	_changed()
	return recovery_conflict

func allow_recovered_draft() -> void:
	if recovery_conflict:
		recovery_conflict = false
		_changed()

func serialize() -> Dictionary:
	return {"schema": 1, "revision": revision, "baseline_head": baseline_head, "remote_origin": remote_origin.duplicate(true), "conflict_handoff": conflict_handoff.duplicate(true), "pending_conflict_local": pending_conflict_local.duplicate(true), "recovery_conflict": recovery_conflict, "content": content.duplicate(true), "applied_content": applied_content.duplicate(true), "source_draft": source_draft, "scenario_draft": scenario_draft, "scenario_error": scenario_error, "scene_drafts": scene_drafts.duplicate(true), "scene_errors": scene_errors.duplicate(true), "undo_stack": undo_stack.duplicate(true), "redo_stack": redo_stack.duplicate(true)}

func restore(data: Dictionary) -> bool:
	if data.get("schema") != 1 or not data.get("content") is Dictionary or not data.get("applied_content") is Dictionary or not data.get("source_draft") is String:
		return false
	if not data.get("undo_stack") is Array or not data.get("redo_stack") is Array or not data.get("baseline_head") is String:
		return false
	if not data.get("remote_origin", {}) is Dictionary or not data.get("conflict_handoff", {}) is Dictionary or not data.get("pending_conflict_local", {}) is Dictionary:
		return false
	if not Content.validate(data.applied_content).is_empty():
		return false
	for stack in [data.undo_stack, data.redo_stack]:
		for operation in stack:
			if not operation is Dictionary or not operation.get("state") is Dictionary or not operation.get("label") is String:
				return false
	content = data.content.duplicate(true)
	applied_content = data.applied_content.duplicate(true)
	source_draft = str(data.source_draft)
	scenario_draft = str(data.get("scenario_draft", JSON.stringify(content, "\t")))
	scenario_error = str(data.get("scenario_error", ""))
	scene_drafts = data.get("scene_drafts", {}).duplicate(true)
	scene_errors = data.get("scene_errors", {}).duplicate(true)
	_sync_scene_drafts()
	undo_stack.assign(data.undo_stack)
	redo_stack.assign(data.redo_stack)
	baseline_head = str(data.baseline_head)
	remote_origin = data.get("remote_origin", {}).duplicate(true)
	conflict_handoff = data.get("conflict_handoff", {}).duplicate(true)
	pending_conflict_local = data.get("pending_conflict_local", {}).duplicate(true)
	recovery_conflict = bool(data.get("recovery_conflict", false))
	revision = int(data.get("revision", 0))
	source_group_open = false
	scenario_group_open = false
	scene_group_open = ""
	return true

func _snapshot() -> Dictionary:
	return {"content": content.duplicate(true), "source_draft": source_draft, "scenario_draft": scenario_draft, "scenario_error": scenario_error, "scene_drafts": scene_drafts.duplicate(true), "scene_errors": scene_errors.duplicate(true)}

func _restore(snapshot: Dictionary) -> void:
	content = snapshot.content.duplicate(true)
	source_draft = str(snapshot.source_draft)
	scenario_draft = str(snapshot.get("scenario_draft", JSON.stringify(content, "\t")))
	scenario_error = str(snapshot.get("scenario_error", ""))
	scene_drafts = snapshot.get("scene_drafts", {}).duplicate(true)
	scene_errors = snapshot.get("scene_errors", {}).duplicate(true)
	_sync_scene_drafts()

func _record(label: String, previous: Dictionary) -> void:
	undo_stack.append({"label": label, "state": previous})
	redo_stack.clear()

func _changed() -> void:
	revision += 1
	changed.emit()

# Visual edits use the same draft/undo transaction as source and remote edits.
func _edit_result(next_content: Dictionary, label: String, id: String = "") -> Dictionary:
	replace_content(next_content, label)
	return {"ok": true, "reason": label, "id": id}

func _edit_error(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func _find_entry(entries: Array, id: String) -> Dictionary:
	for entry in entries:
		if entry.id == id: return entry
	return {}

func create_room() -> Dictionary:
	var next := content.duplicate(true)
	var number: int = next.rooms.size() + 1
	while not _find_entry(next.rooms, "room_%d" % number).is_empty(): number += 1
	var id := "room_%d" % number
	next.rooms.append({"id": id, "name": "Room %d" % number, "bounds": [0, 0, 440, 280], "walkable": [[0, 0, 440, 280]]})
	return _edit_result(next, "Create room %s" % id, id)

func add_walkable_region(room_id: String, start: Vector2, finish: Vector2) -> Dictionary:
	var size := (finish - start).abs()
	if size.x < 4.0 or size.y < 4.0: return _edit_error("Walkable regions must be at least 4 by 4.")
	var next := content.duplicate(true)
	var room := _find_entry(next.rooms, room_id)
	if room.is_empty(): return _edit_error("Room does not exist.")
	if not room.has("walkable"): room.walkable = [room.bounds.duplicate(true)]
	room.walkable.append([minf(start.x, finish.x), minf(start.y, finish.y), size.x, size.y])
	return _edit_result(next, "Draw walkable region", room_id)

func move_walkable_region(room_id: String, index: int, delta: Vector2) -> Dictionary:
	var next := content.duplicate(true)
	var room := _find_entry(next.rooms, room_id)
	if room.is_empty(): return _edit_error("Room does not exist.")
	var had_walkable := room.has("walkable")
	if not had_walkable: room.walkable = [room.bounds.duplicate(true)]
	if index < 0 or index >= room.walkable.size(): return _edit_error("Walkable region does not exist.")
	var values: Array = room.walkable[index]
	var previous := Vector2(float(values[0]), float(values[1]))
	var bounds: Array = room.bounds
	values[0] = clampf(float(values[0]) + delta.x, float(bounds[0]), float(bounds[0]) + float(bounds[2]) - float(values[2]))
	values[1] = clampf(float(values[1]) + delta.y, float(bounds[1]), float(bounds[1]) + float(bounds[3]) - float(values[3]))
	if not had_walkable and previous == Vector2(float(values[0]), float(values[1])): room.erase("walkable")
	return _edit_result(next, "Move walkable region", room_id)

func remove_walkable_region(room_id: String, index: int) -> Dictionary:
	var next := content.duplicate(true)
	var room := _find_entry(next.rooms, room_id)
	if room.is_empty(): return _edit_error("Room does not exist.")
	if not room.has("walkable"): room.walkable = [room.bounds.duplicate(true)]
	if index < 0 or index >= room.walkable.size(): return _edit_error("Walkable region does not exist.")
	room.walkable.remove_at(index)
	return _edit_result(next, "Remove walkable region", room_id)

func connect_rooms(from_room: String, from_point: Vector2, to_room: String, to_point: Vector2) -> Dictionary:
	if from_room == to_room: return _edit_error("Select a different room for the paired door.")
	if _find_entry(content.rooms, from_room).is_empty() or _find_entry(content.rooms, to_room).is_empty(): return _edit_error("Room does not exist.")
	var next := content.duplicate(true)
	var base := "%s_%s" % [from_room, to_room]
	var id := base
	var suffix := 2
	while not _find_entry(next.connections, id).is_empty():
		id = "%s_%d" % [base, suffix]
		suffix += 1
	next.connections.append({"id": id, "from": from_room, "to": to_room, "from_x": from_point.x, "from_y": from_point.y, "to_x": to_point.x, "to_y": to_point.y})
	return _edit_result(next, "Connect %s to %s" % [from_room, to_room], id)

func _nearest_door(data: Dictionary, room_id: String, point: Vector2) -> Dictionary:
	var nearest := {"index": -1, "side": "", "distance": INF}
	for index in data.connections.size():
		var connection: Dictionary = data.connections[index]
		for side in ["from", "to"]:
			if connection[side] != room_id: continue
			var endpoint := Vector2(float(connection.get(side + "_x")), float(connection.get(side + "_y", 160.0)))
			var distance := endpoint.distance_to(point)
			if distance < float(nearest.distance): nearest = {"index": index, "side": side, "distance": distance}
	return nearest

func move_nearest_door(room_id: String, point: Vector2) -> Dictionary:
	var next := content.duplicate(true)
	var nearest := _nearest_door(next, room_id, point)
	if nearest.index < 0: return _edit_error("This room has no door endpoint to move.")
	var connection: Dictionary = next.connections[nearest.index]
	connection[nearest.side + "_x"] = point.x
	connection[nearest.side + "_y"] = point.y
	return _edit_result(next, "Move %s door in %s" % [connection.id, room_id], str(connection.id))

func remove_nearest_door(room_id: String, point: Vector2) -> Dictionary:
	var next := content.duplicate(true)
	var nearest := _nearest_door(next, room_id, point)
	if nearest.index < 0 or nearest.distance > 20.0: return _edit_error("Click near a door endpoint to remove it.")
	var id := str(next.connections[nearest.index].id)
	next.connections.remove_at(nearest.index)
	return _edit_result(next, "Remove door %s" % id, id)

func place_interaction(room_id: String, point: Vector2, effect: String, label: String, duration: int, effect_ticks: int) -> Dictionary:
	if _find_entry(content.rooms, room_id).is_empty(): return _edit_error("Room does not exist.")
	if effect not in ["delay_guest", "close_valve"]: return _edit_error("Unknown interaction effect.")
	var next := content.duplicate(true)
	var id := "guest_signal" if effect == "delay_guest" else "valve"
	var entry := _find_entry(next.interactions, id)
	if entry.is_empty():
		entry = {"id": id, "radius": 60.0}
		next.interactions.append(entry)
	entry.merge({"room": room_id, "x": point.x, "y": point.y, "label": label.strip_edges(), "duration_ticks": duration, "effect": effect}, true)
	if effect == "delay_guest": entry.effect_ticks = effect_ticks
	else: entry.erase("effect_ticks")
	return _edit_result(next, "Place %s interaction in %s" % [id, room_id], id)

func place_actor(id: String, room_id: String, point: Vector2, sprite: String) -> Dictionary:
	id = id.strip_edges()
	if id.is_empty() or id == "amelia": return _edit_error("Enter a non-player actor ID before placement.")
	if _find_entry(content.rooms, room_id).is_empty(): return _edit_error("Room does not exist.")
	var next := content.duplicate(true)
	var entry := _find_entry(next.actors, id)
	if entry.is_empty():
		entry = {"id": id}
		next.actors.append(entry)
	entry.merge({"room": room_id, "x": point.x, "y": point.y, "sprite": sprite}, true)
	return _edit_result(next, "Place actor %s" % id, id)

func schedule_commitment(id: String, actor: String, at_tick: int, room_id: String, point: Vector2, speed: float) -> Dictionary:
	id = id.strip_edges()
	actor = actor.strip_edges()
	if id.is_empty() or actor.is_empty(): return _edit_error("Enter an actor ID and commitment ID before scheduling.")
	if _find_entry(content.rooms, room_id).is_empty(): return _edit_error("Room does not exist.")
	var next := content.duplicate(true)
	var entry := _find_entry(next.commitments, id)
	if entry.is_empty():
		entry = {"id": id}
		next.commitments.append(entry)
	entry.merge({"actor": actor, "at_tick": at_tick, "room": room_id, "x": point.x, "y": point.y, "speed": speed}, true)
	return _edit_result(next, "Schedule %s at tick %d" % [id, at_tick], id)

func retime_commitment(id: String, at_tick: int) -> Dictionary:
	var next := content.duplicate(true)
	var entry := _find_entry(next.commitments, id)
	if entry.is_empty(): return _edit_error("Commitment does not exist.")
	entry.at_tick = at_tick
	return _edit_result(next, "Move %s to tick %d" % [id, at_tick], id)

func save_storylet(id: String, scene_id: String, room_id: String, required_actors: Array, start_tick: int, end_tick: int, required_flags: Dictionary) -> Dictionary:
	id = id.strip_edges()
	scene_id = scene_id.strip_edges()
	if id.is_empty() or scene_id.is_empty(): return _edit_error("Enter both a storylet ID and scene ID.")
	if _find_entry(content.rooms, room_id).is_empty(): return _edit_error("Room does not exist.")
	var required: Array[String] = []
	for raw_id in required_actors:
		var actor_id := str(raw_id).strip_edges()
		if not actor_id.is_empty() and not required.has(actor_id): required.append(actor_id)
	var next := content.duplicate(true)
	var entry := _find_entry(next.get("storylets", []), id)
	if entry.is_empty():
		entry = {"id": id}
		if not next.has("storylets"): next.storylets = []
		next.storylets.append(entry)
	entry.merge({"scene": scene_id, "label": id.capitalize(), "room": room_id, "required_actors": required, "start_tick": start_tick, "end_tick": end_tick, "required_flags": required_flags.duplicate(true), "priority": 0}, true)
	return _edit_result(next, "Save storylet %s" % id, id)

func import_background(room_id: String, name: String, bytes: PackedByteArray) -> Dictionary:
	if _find_entry(content.rooms, room_id).is_empty(): return _edit_error("Room does not exist.")
	var imported := ProjectAssets.import_image(name, bytes)
	if not imported.ok: return imported
	var next := content.duplicate(true)
	if not next.has("assets"): next.assets = {}
	next.assets[imported.id] = imported.asset
	_find_entry(next.rooms, room_id).background_asset = imported.id
	return _edit_result(next, "Import %s background" % room_id, str(imported.id))
