extends RefCounted
class_name FoundationSimulation

const Content = preload("res://foundation/content.gd")
const Dialogue = preload("res://foundation/dialogue.gd")

const TICKS_PER_HOUR := 1800
const LEG_TICKS := TICKS_PER_HOUR * 6
const DIALOGUE_TICKS := 10

var content: Dictionary
var state: Dictionary
var events: Array[Dictionary] = []
var dialogue_steps: Array[Dictionary] = []
var history: Array[Dictionary] = []
var content_versions: Dictionary = {}

func _init(scenario: Dictionary = {}) -> void:
	content = scenario.duplicate(true) if not scenario.is_empty() else Content.scenario()
	var errors: Array[String] = Content.validate(content)
	if not errors.is_empty():
		push_error("Invalid scenario: " + "; ".join(errors))
		return
	var actor_ids: Array[String] = []
	for actor in content.actors: actor_ids.append(actor.id)
	dialogue_steps.assign(Dialogue.parse(str(content.dialogue), actor_ids).steps)
	content_versions[content.version] = content.duplicate(true)
	var actor_state := {}
	for actor in content.actors:
		actor_state[actor.id] = {"room": actor.room, "x": float(actor.x), "y": float(actor.y), "activity": "idle", "destination": ""}
	state = {"tick": 0, "loop_index": 0, "code": _code_for_loop(0), "actors": actor_state, "commitments_started": [], "completed_world_commands": [], "flags": {}, "action": {}, "dialogue": {}, "diary_observations": [], "current_knowledge": [], "content_version": content.version, "events": [], "diagnostics": {}}
	_record_diagnostics()
	history.append(inspect())

func inspect() -> Dictionary:
	return state.duplicate(true)

func tick(input: Dictionary = {}) -> Dictionary:
	if state.is_empty() or state.tick >= LEG_TICKS:
		return inspect()
	events.clear()
	state.tick += 1
	_move_amelia(input)
	_advance_action(input)
	_advance_dialogue(input)
	_start_commitments()
	_move_npcs()
	if state.tick % TICKS_PER_HOUR == 0:
		_emit("hour_boundary", "", "Hour 6 complete" if state.tick == LEG_TICKS else "Hour %d" % (1 + int(state.tick / TICKS_PER_HOUR)))
	if state.tick == LEG_TICKS:
		_emit("leg_end", "", "End of six-Hour demonstration")
	state.events = events.duplicate(true)
	_record_diagnostics()
	history.append(inspect())
	return inspect()

func inspect_at(tick_number: int) -> Dictionary:
	if tick_number < 0 or tick_number >= history.size():
		return {}
	return history[tick_number].duplicate(true)

func restore_record(record: Dictionary) -> bool:
	if not record.get("ok", false): return false
	var restored_content: Dictionary = record.content
	if not Content.validate(restored_content).is_empty(): return false
	content = restored_content.duplicate(true)
	content_versions = record.get("content_versions", {content.version: content}).duplicate(true)
	var actor_ids: Array[String] = []
	for actor in content.actors: actor_ids.append(actor.id)
	dialogue_steps.assign(Dialogue.parse(str(content.dialogue), actor_ids).steps)
	history.clear()
	for snapshot in record.history: history.append(_normalize_snapshot(snapshot))
	state = _normalize_snapshot(record.get("current", history[-1]))
	events.clear()
	return true

func _normalize_snapshot(source: Dictionary) -> Dictionary:
	var snapshot := source.duplicate(true)
	snapshot.tick = int(snapshot.tick)
	snapshot.loop_index = int(snapshot.get("loop_index", 0))
	if not snapshot.action.is_empty():
		snapshot.action.progress = int(snapshot.action.progress)
		snapshot.action.duration = int(snapshot.action.duration)
	if not snapshot.dialogue.is_empty():
		snapshot.dialogue.cursor = int(snapshot.dialogue.cursor)
		snapshot.dialogue.remaining = int(snapshot.dialogue.remaining)
	if snapshot.flags.has("guest_delay_ticks"):
		snapshot.flags.guest_delay_ticks = int(snapshot.flags.guest_delay_ticks)
	for event in snapshot.events:
		event.tick = int(event.tick)
	return snapshot

func reset_loop() -> void:
	var observations: Array = state.diary_observations.duplicate(true)
	var next_loop: int = int(state.loop_index) + 1
	var fresh := FoundationSimulation.new(content)
	state = fresh.state.duplicate(true)
	state.diary_observations = observations
	state.loop_index = next_loop
	state.code = _code_for_loop(next_loop)
	history.clear()
	history.append(inspect())
	events.clear()
	content_versions = {content.version: content.duplicate(true)}

func _code_for_loop(index: int) -> String:
	var value := 32541 + index * 7919
	var digits := ""
	for i in range(5):
		digits = str(value % 6 + 1) + digits
		value = int(value / 6)
	return digits

func continue_with_content(next_content: Dictionary, from_tick: int = -1) -> Dictionary:
	var errors: Array[String] = Content.validate(next_content)
	if not errors.is_empty():
		return {"ok": false, "reason": "; ".join(errors), "restart": false}
	if content_versions.has(next_content.version) and content_versions[next_content.version] != next_content:
		return {"ok": false, "reason": "Content version ID already names different content", "restart": false}
	var target_tick: int = int(state.tick) if from_tick < 0 else from_tick
	if target_tick < 0 or target_tick >= history.size():
		return {"ok": false, "reason": "Recorded tick does not exist", "restart": false}
	var restored: Dictionary = history[target_tick]
	var old_actor_ids := []
	var new_actor_ids := []
	for actor in content.actors: old_actor_ids.append(actor.id)
	for actor in next_content.actors: new_actor_ids.append(actor.id)
	old_actor_ids.sort()
	new_actor_ids.sort()
	if old_actor_ids != new_actor_ids:
		return {"ok": false, "reason": "Actor IDs changed; restart the leg", "restart": true}
	var historical_content: Dictionary = content_versions.get(restored.content_version, {})
	if historical_content.is_empty():
		return {"ok": false, "reason": "Historical content version is unavailable; restart the leg", "restart": true}
	if not restored.action.is_empty():
		var old_interaction := _find_interaction(historical_content, str(restored.action.id))
		var new_interaction := _find_interaction(next_content, str(restored.action.id))
		if old_interaction != new_interaction:
			return {"ok": false, "reason": "Active action structure changed; restart the leg", "restart": true}
	if not restored.dialogue.is_empty() and historical_content.dialogue != next_content.dialogue:
		return {"ok": false, "reason": "Active dialogue changed; restart the leg", "restart": true}
	var actor_ids: Array[String] = []
	for actor in next_content.actors: actor_ids.append(actor.id)
	var next_steps: Array[Dictionary] = []
	next_steps.assign(Dialogue.parse(str(next_content.dialogue), actor_ids).steps)
	state = restored.duplicate(true)
	content = next_content.duplicate(true)
	content_versions[content.version] = content.duplicate(true)
	dialogue_steps = next_steps
	state.content_version = content.version
	if target_tick < history.size() - 1:
		history.resize(target_tick + 1)
	return {"ok": true, "reason": "Continued from tick %d" % target_tick, "restart": false}

func _find_interaction(in_content: Dictionary, id: String) -> Dictionary:
	for interaction in in_content.interactions:
		if interaction.id == id:
			return interaction
	return {}

func step_next_event() -> Dictionary:
	while state.tick < LEG_TICKS:
		tick()
		if not events.is_empty():
			return inspect()
	return inspect()

func _record_diagnostics() -> void:
	var npc: Dictionary = {}
	for actor_id in state.actors:
		if actor_id == "amelia": continue
		var actor: Dictionary = state.actors[actor_id]
		npc[actor_id] = {"room": actor.room, "activity": actor.activity, "destination": actor.destination, "reason": "Following authored commitment" if not str(actor.destination).is_empty() else "Waiting for next commitment"}
	state.diagnostics = {"npc": npc, "storylets": {"valve": "Completed" if state.flags.get("close_valve", false) else "Available when Amelia is nearby", "conversation": "Current-loop lead known" if state.current_knowledge.has("guest_will_wait") else "Lead not yet heard"}, "content_version": content.version}

func _emit(category: String, actor_id: String, detail: String) -> void:
	events.append({"tick": state.tick, "category": category, "actor": actor_id, "detail": detail})

func available_interactions() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	if not state.dialogue.is_empty(): return available
	var amelia: Dictionary = state.actors.amelia
	for interaction in content.interactions:
		if interaction.room != amelia.room or state.flags.get(interaction.effect, false):
			continue
		if Vector2(float(amelia.x), float(amelia.y)).distance_to(Vector2(float(interaction.x), float(interaction.y))) <= float(interaction.radius):
			available.append(interaction.duplicate(true))
	return available

func _advance_action(input: Dictionary) -> void:
	if not state.action.is_empty():
		var action: Dictionary = state.action
		var interaction := _interaction(str(action.id))
		if bool(input.get("cancel_action", false)):
			_cancel_action("Interrupted by Amelia")
		elif interaction.is_empty() or not _interaction_available(interaction):
			_cancel_action("Conditions no longer hold")
		else:
			action.progress += 1
			if action.progress >= int(interaction.duration_ticks):
				state.flags[interaction.effect] = true
				_emit("action_completed", "amelia", str(action.id))
				state.action = {}
	if state.action.is_empty() and input.has("start_interaction"):
		var interaction := _interaction(str(input.start_interaction))
		if not interaction.is_empty() and _interaction_available(interaction):
			state.action = {"id": interaction.id, "progress": 0, "duration": int(interaction.duration_ticks)}
			_emit("action_started", "amelia", str(interaction.id))
		else:
			_emit("action_rejected", "amelia", "Interaction unavailable: " + str(input.start_interaction))

func _cancel_action(reason: String) -> void:
	_emit("action_cancelled", "amelia", str(state.action.id) + ": " + reason)
	state.action = {}

func dialogue_available() -> bool:
	var amelia: Dictionary = state.actors.amelia
	var chatterbox: Dictionary = state.actors.chatterbox
	return state.dialogue.is_empty() and state.action.is_empty() and amelia.room == chatterbox.room and Vector2(float(amelia.x), float(amelia.y)).distance_to(Vector2(float(chatterbox.x), float(chatterbox.y))) <= 65.0

func _advance_dialogue(input: Dictionary) -> void:
	if bool(input.get("start_dialogue", false)) and dialogue_available():
		state.dialogue = {"cursor": 0, "remaining": 0, "line": _line_text(0), "completed_commands": []}
		_observe_line(0)
		_emit("dialogue_started", "chatterbox", "start")
		return
	if state.dialogue.is_empty():
		return
	var dialogue: Dictionary = state.dialogue
	if int(dialogue.remaining) > 0:
		dialogue.remaining -= 1
		if int(dialogue.remaining) == 0:
			var next_cursor: int = int(dialogue.cursor) + 1
			if next_cursor >= dialogue_steps.size():
				_emit("dialogue_finished", "amelia", "start")
				state.dialogue = {}
			else:
				for command_index in dialogue_steps[next_cursor].commands_before.size():
					var command: Dictionary = dialogue_steps[next_cursor].commands_before[command_index]
					var command_key := "%d:%d" % [next_cursor, command_index]
					if not dialogue.completed_commands.has(command_key) and not state.completed_world_commands.has(command_key):
						_apply_dialogue_command(command)
						dialogue.completed_commands.append(command_key)
						state.completed_world_commands.append(command_key)
				dialogue.cursor = next_cursor
				dialogue.line = _line_text(next_cursor)
				_observe_line(next_cursor)
				_emit("dialogue_line", str(dialogue_steps[next_cursor].speaker), str(dialogue.line))
	elif bool(input.get("advance_dialogue", false)):
		dialogue.remaining = DIALOGUE_TICKS
		_emit("dialogue_step_started", "amelia", str(dialogue.cursor))

func _line_text(cursor: int) -> String:
	return "%s: %s" % [dialogue_steps[cursor].speaker, dialogue_steps[cursor].text]

func _observe_line(cursor: int) -> void:
	var key := "%s:%d" % [content.version, cursor]
	if not state.diary_observations.has(key):
		state.diary_observations.append(key)

func _apply_dialogue_command(command: Dictionary) -> void:
	if command.name == "delay_guest":
		state.flags.guest_delay_ticks = int(state.flags.get("guest_delay_ticks", 0)) + int(command.ticks)
		if not state.current_knowledge.has("guest_will_wait"):
			state.current_knowledge.append("guest_will_wait")
		_emit("dialogue_command", "guest", "delay_guest(%d)" % int(command.ticks))

func _interaction(id: String) -> Dictionary:
	for interaction in content.interactions:
		if interaction.id == id:
			return interaction
	return {}

func _interaction_available(interaction: Dictionary) -> bool:
	var amelia: Dictionary = state.actors.amelia
	return state.dialogue.is_empty() and amelia.room == interaction.room and not state.flags.get(interaction.effect, false) and Vector2(float(amelia.x), float(amelia.y)).distance_to(Vector2(float(interaction.x), float(interaction.y))) <= float(interaction.radius)

func _move_amelia(input: Dictionary) -> void:
	var direction := Vector2(float(input.get("x", 0.0)), float(input.get("y", 0.0))).limit_length()
	var amelia: Dictionary = state.actors.amelia
	amelia.x = clampf(amelia.x + direction.x * 4.0, 0.0, 440.0)
	amelia.y = clampf(amelia.y + direction.y * 4.0, 0.0, 280.0)
	for connection in content.connections:
		if amelia.room == connection.from and amelia.x >= float(connection.from_x) and direction.x > 0.0:
			amelia.room = connection.to
			amelia.x = float(connection.to_x)
			_emit("room_transition", "amelia", str(connection.id))
			break
		if amelia.room == connection.to and amelia.x <= float(connection.to_x) and direction.x < 0.0:
			amelia.room = connection.from
			amelia.x = float(connection.from_x)
			_emit("room_transition", "amelia", str(connection.id))
			break

func _start_commitments() -> void:
	for commitment in content.commitments:
		var start_tick: int = int(commitment.at_tick)
		if commitment.id == "chatterbox_crossing" and state.flags.get("close_valve", false):
			start_tick += 40
		if commitment.id == "guest_visit":
			start_tick += int(state.flags.get("guest_delay_ticks", 0))
			if state.flags.get("close_valve", false):
				start_tick += 20
		if state.tick != start_tick or state.commitments_started.has(commitment.id):
			continue
		state.commitments_started.append(commitment.id)
		var actor: Dictionary = state.actors[commitment.actor]
		actor.activity = "travel"
		actor.destination = commitment.id
		_emit("commitment", commitment.actor, commitment.id)

func _move_npcs() -> void:
	for commitment in content.commitments:
		var actor: Dictionary = state.actors[commitment.actor]
		if actor.destination != commitment.id:
			continue
		var target_room: String = commitment.room
		var target_x: float = float(commitment.x)
		if actor.room != target_room:
			var connection := _connection(actor.room, target_room)
			if connection.is_empty():
				actor.activity = "blocked"
				_emit("blocked", commitment.actor, "No connection to " + target_room)
				continue
			var exit_x: float = float(connection.from_x if actor.room == connection.from else connection.to_x)
			actor.x = move_toward(float(actor.x), exit_x, float(commitment.speed))
			if is_equal_approx(float(actor.x), exit_x):
				actor.room = target_room
				actor.x = float(connection.to_x if target_room == connection.to else connection.from_x)
				_emit("room_transition", commitment.actor, str(connection.id))
		else:
			actor.x = move_toward(float(actor.x), target_x, float(commitment.speed))
			if is_equal_approx(float(actor.x), target_x):
				actor.activity = "idle"
				actor.destination = ""
				_emit("arrival", commitment.actor, commitment.id)

func _connection(from_room: String, to_room: String) -> Dictionary:
	for connection in content.connections:
		if connection.from == from_room and connection.to == to_room or connection.to == from_room and connection.from == to_room:
			return connection
	return {}
