extends RefCounted
class_name FoundationScenario

const Content = preload("res://foundation/content.gd")
const Dialogue = preload("res://foundation/dialogue.gd")

var source: Dictionary
var dialogue_steps: Array[Dictionary] = []

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
	return {"ok": true, "scenario": result}

func interaction(id: String) -> Dictionary:
	for item in source.interactions:
		if item.id == id:
			return item
	return {}

func interaction_available(item: Dictionary, state: Dictionary) -> bool:
	var amelia: Dictionary = state.actors.amelia
	return state.dialogue.is_empty() and amelia.room == item.room and not state.flags.get(item.effect, false) and Vector2(float(amelia.x), float(amelia.y)).distance_to(Vector2(float(item.x), float(item.y))) <= float(item.radius)

func available_interactions(state: Dictionary) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	if not state.dialogue.is_empty():
		return available
	for item in source.interactions:
		if interaction_available(item, state):
			available.append(item.duplicate(true))
	return available

func dialogue_available(state: Dictionary) -> bool:
	var amelia: Dictionary = state.actors.amelia
	var chatterbox: Dictionary = state.actors.chatterbox
	return state.dialogue.is_empty() and state.action.is_empty() and amelia.room == chatterbox.room and Vector2(float(amelia.x), float(amelia.y)).distance_to(Vector2(float(chatterbox.x), float(chatterbox.y))) <= 65.0

func complete_interaction(item: Dictionary, state: Dictionary) -> void:
	state.flags[item.effect] = true

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

func diagnostics(state: Dictionary) -> Dictionary:
	var npc: Dictionary = {}
	for actor_id in state.actors:
		if actor_id == "amelia":
			continue
		var actor: Dictionary = state.actors[actor_id]
		npc[actor_id] = {"room": actor.room, "activity": actor.activity, "destination": actor.destination, "reason": "Following authored commitment" if not str(actor.destination).is_empty() else "Waiting for next commitment"}
	return {"npc": npc, "storylets": {"valve": "Completed" if state.flags.get("close_valve", false) else "Available when Amelia is nearby", "conversation": "Current-loop lead known" if state.current_knowledge.has("guest_will_wait") else "Lead not yet heard"}, "content_version": source.version}
