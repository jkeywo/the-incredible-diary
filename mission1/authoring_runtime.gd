extends RefCounted
## Authored rules execute within the existing Mission 1 simulation.
const Content = preload("res://mission1/authoring_content.gd")
const Grid = preload("res://mission1/authoring_grid.gd")
const Speech = preload("res://mission1/conversations.gd")
const Dialogue = preload("res://foundation/dialogue.gd")

static func conditions(items: Array, state: Dictionary) -> Array:
	var result := []
	for item in items:
		var actual: Variant = null
		if item.has("flag"): actual = state.flags.get(item.flag, false)
		elif item.has("actor"): actual = state.get("actors", {}).get(item.actor, {}).get(item.get("field","room"), "")
		elif item.has("prop"): actual = state.get("prop_states", {}).get(item.prop, "")
		elif item.has("safe"): actual = state.safe.has(item.safe)
		elif item.has("dead"): actual = state.dead.has(item.dead)
		elif item.has("has_flag"): actual = state.flags.has(item.has_flag)
		elif item.has("distance"):
			var actors: Dictionary = state.get("actors",{}).duplicate()
			actors.amelia = {"room":state.room,"pos":state.pos}
			var first: Dictionary = actors.get(item.distance[0],{})
			var second: Dictionary = actors.get(item.distance[1],{})
			actual = not first.is_empty() and not second.is_empty() and first.room == second.room and Vector2(first.pos[0],first.pos[1]).distance_to(Vector2(second.pos[0],second.pos[1])) <= float(item.maximum)
		result.append({"condition":item.duplicate(true), "actual":actual, "passed":actual == item.get("equals", true)})
	return result

static func eligible(story: Dictionary, state: Dictionary) -> Dictionary:
	var checks := conditions(story.get("conditions", []), state)
	checks.append({"condition":"time window", "passed":int(state.tick) >= int(story.get("start_tick", 0)) and int(state.tick) <= int(story.get("end_tick", 10800))})
	checks.append({"condition":"not already completed", "passed":story.get("repeat", false) or not state.get("completed_storylets", []).has(story.id)})
	for id in story.get("participants", []):
		var present: bool = id == "amelia" or state.get("actors", {}).has(id)
		var room: String = state.room if id == "amelia" else str(state.get("actors", {}).get(id, {}).get("room", ""))
		checks.append({"condition":"participant " + str(id), "passed":present and (str(story.get("room", "")).is_empty() or room == story.room) and not state.dead.has(id)})
	var allowed := true
	for check in checks: allowed = allowed and check.passed
	return {"eligible":allowed, "conditions":checks}

static func update(run) -> void:
	if run.authored_content.is_empty(): return
	var content: Dictionary = run.authored_content
	if not run.s.has("completed_storylets"): run.s.completed_storylets = []
	if not run.s.has("prop_states"): run.s.prop_states = {}
	var diagnostic: Dictionary = run.s.get("authoring_diagnostics", {}).duplicate(true)
	var stories: Array = content.storylets.duplicate()
	stories.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)) if a.get("priority", 0) != b.get("priority", 0) else str(a.id) < str(b.id))
	for story in stories:
		if story.get("phase", "frame") != "frame": continue
		var status := eligible(story, run.s)
		diagnostic[story.id] = status
		if not status.eligible or not str(story.get("scene", "")).is_empty() and not run.s.get("conversation", {}).is_empty(): continue
		for effect in story.get("effects", []):
			match effect.command:
				"flag": run.s.flags[str(effect.key)] = effect.get("value", true)
				"prop": run.s.prop_states[str(effect.entity)] = str(effect.state)
				"say": Speech.say(run, str(effect.actor), str(effect.text))
				"note": run.note(str(effect.key), str(effect.text))
				"mission": run.execute_mission_effect(str(effect.operation))
		var scene_id := str(story.get("scene", ""))
		if not scene_id.is_empty():
			var ids: Array[String] = []
			for id in content.instances: ids.append(str(id))
			var parsed := Dialogue.parse(content.scenes[scene_id], ids)
			var lines := []
			for step in parsed.steps: lines.append([str(step.speaker).to_lower(), step.text, step.commands_before])
			Speech.start(run, "authored:" + str(story.id), lines, story.get("participants", []))
		if not run.s.completed_storylets.has(story.id): run.s.completed_storylets.append(story.id)
		run.events.append({"kind":"storylet", "text":story.id})
	for id in content.instances:
		var entity := Content.resolve(content, id)
		if entity.kind == "character": continue
		var state := str(run.s.prop_states.get(id,entity.get("initial_state", "idle")))
		for transition in entity.get("transitions", []):
			if transition.has("from") and transition.from != state: continue
			var allowed := true
			for check in conditions(transition.get("conditions", []), run.s): allowed = allowed and check.passed
			if allowed: state = str(transition.state)
		run.s.prop_states[id] = state
		run.s["content_version"] = content.version
	run.s["authoring_diagnostics"] = diagnostic
	var actor_diagnostics := {}
	for id in run.s.get("actors",{}):
		var actor: Dictionary = run.s.actors[id]
		var schedule: Dictionary = content.schedules.get(id,{})
		var next := {}
		for commitment in schedule.get("commitments",[]):
			if commitment.tick > run.s.tick and (next.is_empty() or commitment.tick < next.tick): next = commitment.duplicate(true)
		for stage in schedule.get("stages",[]):
			if stage[0] is Dictionary: continue
			if stage[0] > run.s.tick and (next.is_empty() or stage[0] < next.tick): next = {"tick":stage[0],"room":stage[1],"position":stage[2]}
		actor_diagnostics[id] = {"activity":actor.get("action","idle"),"room":actor.room,"next_commitment":next}
	run.s.actor_diagnostics = actor_diagnostics

static func execute_phase(run, phase: String) -> void:
	if not run.s.has("completed_storylets"): run.s.completed_storylets = []
	if not run.s.has("authoring_diagnostics"): run.s.authoring_diagnostics = {}
	var stories: Array = run.authored_content.storylets.duplicate()
	stories.sort_custom(func(a,b): return int(a.get("priority",0)) > int(b.get("priority",0)) if a.get("priority",0) != b.get("priority",0) else str(a.id) < str(b.id))
	for story in stories:
		if story.get("phase", "frame") != phase: continue
		var status := eligible(story,run.s)
		# A shove intentionally brings impact forward; the recorded override is world state.
		if story.id == "chandelier_impact" and run.s.flags.has("chandelier_impact_tick"):
			var adjusted: Dictionary = story.duplicate(true)
			adjusted.start_tick = run.s.flags.chandelier_impact_tick
			status = eligible(adjusted,run.s)
		run.s.authoring_diagnostics[story.id] = status
		if not status.eligible: continue
		for effect in story.get("effects", []):
			match effect.command:
				"mission": run.execute_mission_effect(str(effect.operation))
				"flag": run.s.flags[str(effect.key)] = effect.get("value", true)
				"prop": run.s.get_or_add("prop_states",{})[str(effect.entity)] = str(effect.state)
				"say": Speech.say(run,str(effect.actor),str(effect.text))
				"note": run.note(str(effect.key),str(effect.text))
		if not run.s.completed_storylets.has(story.id): run.s.completed_storylets.append(story.id)

static func play_conversations(run) -> void:
	var stories: Array = run.authored_content.storylets.duplicate()
	stories.sort_custom(func(a,b): return int(a.get("priority",0)) > int(b.get("priority",0)) if a.get("priority",0) != b.get("priority",0) else str(a.id) < str(b.id))
	for story in stories:
		if story.get("phase", "frame") != "conversation": continue
		var status := eligible(story,run.s)
		for id in story.get("participants",[]):
			if run.s.actors.get(id,{}).get("room","") != run.s.room: status.eligible = false
		run.s.get_or_add("authoring_diagnostics",{})[story.id] = status
		if not status.eligible: continue
		var ids: Array[String] = []
		for id in run.authored_content.instances: ids.append(str(id))
		var source: String = run.authored_content.scenes.get(story.get("scene",""),"")
		if source.is_empty(): continue
		var parsed := Dialogue.parse(source,ids)
		var lines := []
		for step in parsed.steps: lines.append([str(step.speaker).to_lower(),step.text,step.commands_before])
		Speech.start(run,story.scene,lines,story.participants)
		if not run.s.has("completed_storylets"): run.s.completed_storylets = []
		run.s.completed_storylets.append(story.id)
		return

static func actors(run, planned: Dictionary) -> Dictionary:
	var content: Dictionary = run.authored_content
	if content.is_empty(): return planned
	for id in content.instances:
		var entity := Content.resolve(content, id)
		if entity.kind != "character" or id == "amelia": continue
		var schedule: Dictionary = content.schedules.get(id, {"mode":"custom", "commitments":[]})
		if schedule.get("mode", "custom") == "mission": continue
		var pose: Dictionary = run.s.get("actors", {}).get(id, {"room":entity.room,"pos":entity.position,"action":"idle","facing":"down"}).duplicate(true)
		var destination := {}
		for commitment in schedule.commitments:
			if commitment.tick <= run.s.tick and (destination.is_empty() or commitment.tick > destination.tick): destination = commitment
		if not destination.is_empty():
			var route: Array = run.Routines.path(pose.room, run.Rooms.point(pose.pos), destination.room, run.Rooms.point(destination.position), false, run.s.flags)
			for waypoint in route:
				if waypoint.room != pose.room:
					pose.room = waypoint.room
					pose.pos = waypoint.pos.duplicate()
					continue
				var delta: Vector2 = run.Rooms.point(waypoint.pos) - run.Rooms.point(pose.pos)
				if delta.length() < 0.1: continue
				var next: Vector2 = run.Rooms.point(pose.pos) + delta.limit_length(float(destination.get("speed", 10)))
				pose.pos = [next.x, next.y]
				pose.action = "walk"
				break
		planned[id] = pose
	return planned

static func compatibility(content: Dictionary, run, state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var occupied: Dictionary = state.get("actors", {}).duplicate(true)
	occupied.amelia = {"room":state.room, "pos":state.pos}
	for id in occupied:
		var actor: Dictionary = occupied[id]
		if not content.instances.has(id): errors.append("Restart required: active entity %s was removed" % id)
		if not content.rooms.has(actor.room) or not Grid.contains(content.rooms[actor.room], Vector2(actor.pos[0], actor.pos[1])): errors.append("Restart required: %s occupies changed collision geometry" % id)
		var previous: Dictionary = run.authored_content.get("instances",{}).get(id,{})
		if not previous.is_empty() and content.instances.has(id):
			var next: Dictionary = content.instances[id]
			if next.room != previous.room or not equivalent(next.position,previous.position): errors.append("Restart required: %s starting placement changed" % id)
	if not run.authored_content.is_empty() and (not state.get("action", {}).is_empty() or not state.get("conversation", {}).is_empty()):
		var conversation: Dictionary = state.get("conversation",{})
		var scene_id := str(conversation.get("id",""))
		if content.scenes.get(scene_id) != run.authored_content.scenes.get(scene_id): errors.append("Restart required: active scene %s changed" % scene_id)
		var participants: Array = conversation.get("people",[]).duplicate()
		var action_id := str(state.get("action",{}).get("id",""))
		if action_id.begins_with("authored:"): participants.append(action_id.split(":")[1])
		elif not action_id.is_empty(): participants.append(run.interaction_target(action_id))
		for id in participants:
			if not equivalent(Content.resolve(content,id),Content.resolve(run.authored_content,id)): errors.append("Restart required: active participant %s changed" % id)
	return errors

static func equivalent(left: Variant, right: Variant) -> bool:
	# JSON stores numbers as floats; compare both sides in the portable representation.
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))

static func options(run, result: Array[Dictionary], local: bool) -> Array[Dictionary]:
	for id in run.authored_content.get("instances",{}):
		var entity := Content.resolve(run.authored_content,id)
		if entity.room != run.s.room: continue
		for index in entity.get("interactions",[]).size():
			var interaction: Dictionary = entity.interactions[index]
			var point: Array = interaction.get("position",entity.position)
			var allowed := true
			for condition in conditions(interaction.get("conditions",[]),run.s): allowed = allowed and condition.passed
			if allowed and (not local or run.nearby(entity.room,Vector2(point[0],point[1]),float(interaction.get("radius",80)))):
				result.append({"id":"authored:%s:%d" % [id,index],"label":interaction.get("label","Interact"),"room":entity.room,"pos":point,"target":id})
	return result

static func interaction(run, id: String) -> Dictionary:
	var parts := id.split(":")
	if parts.size() != 3 or parts[0] != "authored": return {}
	var entity := Content.resolve(run.authored_content,parts[1])
	var items: Array = entity.get("interactions",[])
	var index := int(parts[2])
	return items[index] if index >= 0 and index < items.size() else {}

static func complete_interaction(run, id: String) -> void:
	for effect in interaction(run,id).get("effects",[]):
		match effect.get("command"):
			"flag": run.s.flags[str(effect.key)] = effect.get("value",true)
			"prop": run.s.get_or_add("prop_states",{})[str(effect.entity)] = str(effect.state)
			"say": Speech.say(run,str(effect.actor),str(effect.text))
			"note": run.note(str(effect.key),str(effect.text))
			"mission": run.execute_mission_effect(str(effect.operation))
	run.events.append({"kind":"action", "text":id})
