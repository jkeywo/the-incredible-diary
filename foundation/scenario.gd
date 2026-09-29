extends RefCounted
class_name FoundationScenario

const Content = preload("res://foundation/content.gd")
const Dialogue = preload("res://foundation/dialogue.gd")
const Geometry = preload("res://foundation/room_geometry.gd")

var source: Dictionary
var dialogue_steps: Array[Dictionary] = []
var scene_steps: Dictionary = {}

static func compile(data: Dictionary) -> Dictionary:
	var errors: Array[String] = Content.validate(data)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var result := FoundationScenario.new()
	result.source = data.duplicate(true)
	var actor_ids: Array[String] = []
	for actor in result.source.actors:
		actor_ids.append(actor.id)
	result.dialogue_steps.assign(Dialogue.parse(str(result.source.dialogue), actor_ids).steps)
	for scene_id in result.source.get("scenes", {}):
		result.scene_steps[scene_id] = Dialogue.parse(str(result.source.scenes[scene_id]), actor_ids).steps
	return {"ok": true, "scenario": result}

func interaction(id: String) -> Dictionary:
	for item in source.interactions:
		if item.id == id:
			return item
	return {}

func interaction_available(item: Dictionary, state: Dictionary) -> bool:
	var amelia: Dictionary = state.actors.amelia
	var room := {}
	for candidate in source.rooms:
		if candidate.id == item.room:
			room = candidate
			break
	var origin := Vector2(float(amelia.x), float(amelia.y))
	var target := Vector2(float(item.x), float(item.y))
	if not state.dialogue.is_empty() or amelia.room != item.room or state.get("completed_interactions", []).has(item.id):
		return false
	var route := Geometry.path(room, origin, target)
	if route.is_empty():
		return false
	var distance := 0.0
	var previous := origin
	for waypoint in route:
		distance += previous.distance_to(waypoint)
		previous = waypoint
	return distance <= float(item.radius)

func available_interactions(state: Dictionary) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	if not state.dialogue.is_empty():
		return available
	for item in source.interactions:
		if interaction_available(item, state):
			available.append(item.duplicate(true))
	return available

func dialogue_available(state: Dictionary) -> bool:
	return not available_storylets(state).is_empty()

func available_storylets(state: Dictionary) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	if not state.dialogue.is_empty() or not state.action.is_empty():
		return available
	var amelia: Dictionary = state.actors.amelia
	for storylet in source.get("storylets", []):
		if state.get("completed_storylets", []).has(storylet.id) or int(state.tick) < int(storylet.start_tick) or int(state.tick) > int(storylet.end_tick) or amelia.room != storylet.room:
			continue
		var eligible := true
		for actor_id in storylet.required_actors:
			var actor: Dictionary = state.actors[actor_id]
			if actor.room != storylet.room or Vector2(float(amelia.x), float(amelia.y)).distance_to(Vector2(float(actor.x), float(actor.y))) > 65.0:
				eligible = false
				break
		for flag in storylet.get("required_flags", {}):
			if bool(state.flags.get(flag, false)) != bool(storylet.required_flags[flag]):
				eligible = false
				break
		if eligible:
			available.append({"id": storylet.id, "scene": storylet.scene, "label": storylet.get("label", storylet.id), "priority": int(storylet.get("priority", 0))})
	if _legacy_dialogue_available(state):
		available.append({"id": "legacy", "scene": "legacy", "label": "Talk", "priority": -1000})
	available.sort_custom(func(left: Dictionary, right: Dictionary): return left.priority > right.priority or left.priority == right.priority and str(left.id) < str(right.id))
	return available

func _legacy_dialogue_available(state: Dictionary) -> bool:
	var amelia: Dictionary = state.actors.amelia
	var chatterbox: Dictionary = state.actors.chatterbox
	return state.dialogue.is_empty() and state.action.is_empty() and amelia.room == chatterbox.room and Vector2(float(amelia.x), float(amelia.y)).distance_to(Vector2(float(chatterbox.x), float(chatterbox.y))) <= 65.0

func steps_for(scene_id: String) -> Array[Dictionary]:
	if scene_id == "legacy":
		return dialogue_steps
	var steps: Array[Dictionary] = []
	steps.assign(scene_steps.get(scene_id, []))
	return steps

func complete_interaction(item: Dictionary, state: Dictionary) -> void:
	state.completed_interactions.append(item.id)
	match str(item.effect):
		"close_valve": state.flags.close_valve = true
		"delay_guest": state.flags.guest_delay_ticks = int(state.flags.get("guest_delay_ticks", 0)) + int(item.effect_ticks)

func apply_command(command: Dictionary, state: Dictionary) -> Dictionary:
	if command.name == "delay_guest":
		state.flags.guest_delay_ticks = int(state.flags.get("guest_delay_ticks", 0)) + int(command.ticks)
		if not state.current_knowledge.has("guest_will_wait"):
			state.current_knowledge.append("guest_will_wait")
		return {"actor": "guest", "detail": "delay_guest(%d)" % int(command.ticks)}
	return {}

func commitment_start_tick(commitment: Dictionary, state: Dictionary) -> int:
	var start_tick: int = int(commitment.at_tick)
	if commitment.id == "chatterbox_crossing" and state.flags.get("close_valve", false):
		start_tick += 40
	if commitment.id == "guest_visit":
		start_tick += int(state.flags.get("guest_delay_ticks", 0))
		if state.flags.get("close_valve", false):
			start_tick += 20
	return start_tick

func connection(from_room: String, to_room: String) -> Dictionary:
	for item in source.connections:
		if item.from == from_room and item.to == to_room or item.to == from_room and item.from == to_room:
			return item
	return {}

func connection_open(item: Dictionary, state: Dictionary) -> bool:
	var required := str(item.get("requires_flag", ""))
	return required.is_empty() or bool(state.flags.get(required, false))

func diagnostics(state: Dictionary) -> Dictionary:
	var npc: Dictionary = {}
	for actor_id in state.actors:
		if actor_id == "amelia":
			continue
		var actor: Dictionary = state.actors[actor_id]
		var active: Dictionary = {}
		var next: Dictionary = {}
		for commitment in source.commitments:
			if str(commitment.actor) != str(actor_id):
				continue
			if str(commitment.id) == str(actor.destination):
				active = commitment
			elif not state.commitments_started.has(commitment.id):
				if next.is_empty() or commitment_start_tick(commitment, state) < commitment_start_tick(next, state):
					next = commitment
		var intended: Dictionary = active if not active.is_empty() else next
		var target: Dictionary = {}
		if not intended.is_empty():
			target = {"commitment": intended.id, "room": intended.room, "at_tick": str(commitment_start_tick(intended, state))}
		npc[actor_id] = {"room": actor.room, "activity": actor.activity, "destination": actor.destination, "target": target, "reason": "Following authored commitment" if not active.is_empty() else "Waiting for next commitment" if not next.is_empty() else "No remaining commitment"}
	var storylets: Dictionary = {}
	for storylet in source.get("storylets", []):
		var conditions: Array[Dictionary] = []
		var amelia: Dictionary = state.actors.amelia
		conditions.append({"name": "time", "met": int(state.tick) >= int(storylet.start_tick) and int(state.tick) <= int(storylet.end_tick), "detail": "Ticks %d–%d" % [storylet.start_tick, storylet.end_tick]})
		conditions.append({"name": "room", "met": str(amelia.room) == str(storylet.room), "detail": "Amelia in %s" % storylet.room})
		for actor_id in storylet.required_actors:
			var actor: Dictionary = state.actors[actor_id]
			var nearby := str(actor.room) == str(storylet.room) and Vector2(float(amelia.x), float(amelia.y)).distance_to(Vector2(float(actor.x), float(actor.y))) <= 65.0
			conditions.append({"name": "actor:%s" % actor_id, "met": nearby, "detail": "%s nearby in %s" % [actor_id, storylet.room]})
		for flag in storylet.get("required_flags", {}):
			conditions.append({"name": "flag:%s" % flag, "met": bool(state.flags.get(flag, false)) == bool(storylet.required_flags[flag]), "detail": "%s = %s" % [flag, str(storylet.required_flags[flag])]})
		var unblocked: bool = state.dialogue.is_empty() and state.action.is_empty()
		conditions.append({"name": "activity", "met": unblocked, "detail": "Amelia free to talk"})
		var completed: bool = state.get("completed_storylets", []).has(storylet.id)
		conditions.append({"name": "completion", "met": not completed, "detail": "Not already completed"})
		var eligible := true
		for condition in conditions:
			if not condition.met:
				eligible = false
				break
		storylets[storylet.id] = {"scene": storylet.scene, "label": storylet.get("label", storylet.id), "room": storylet.room, "status": "completed" if completed else "eligible" if eligible else "blocked", "conditions": conditions}
	return {"npc": npc, "storylets": storylets, "content_version": source.version}
