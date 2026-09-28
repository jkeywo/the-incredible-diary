extends RefCounted
class_name FoundationContent

const Dialogue = preload("res://foundation/dialogue.gd")
const Assets = preload("res://foundation/project_assets.gd")
const Geometry = preload("res://foundation/room_geometry.gd")

const SCHEMA := 1

static func scenario() -> Dictionary:
	return {
		"schema": SCHEMA,
		"version": "two-room-1",
		"assets": {},
		"rooms": [
			{"id": "service", "name": "Service Room", "bounds": [0, 0, 440, 280], "walkable": [[0, 0, 440, 280]]},
			{"id": "corridor", "name": "Party Corridor", "bounds": [0, 0, 440, 280], "walkable": [[0, 0, 440, 280]]},
		],
		"connections": [
			{"id": "service_corridor", "from": "service", "to": "corridor", "from_x": 420.0, "to_x": 20.0},
		],
		"actors": [
			{"id": "amelia", "room": "service", "x": 80.0, "y": 160.0},
			{"id": "chatterbox", "room": "service", "x": 180.0, "y": 160.0},
			{"id": "guest", "room": "corridor", "x": 300.0, "y": 160.0},
		],
		"commitments": [
			{"id": "chatterbox_crossing", "actor": "chatterbox", "at_tick": 20, "room": "corridor", "x": 300.0, "speed": 4.0},
			{"id": "chatterbox_return", "actor": "chatterbox", "at_tick": 90, "room": "service", "x": 180.0, "speed": 4.0},
			{"id": "guest_visit", "actor": "guest", "at_tick": 110, "room": "service", "x": 180.0, "speed": 4.0},
		],
		"interactions": [
			{"id": "valve", "room": "service", "x": 330.0, "y": 160.0, "radius": 60.0, "label": "Turn valve", "duration_ticks": 30, "effect": "close_valve"},
		],
		"dialogue": "~ start\nChatterbox: The guest is coming soon.\ndo delay_guest(40)\nAmelia: I asked the guest to wait.\n=> END",
	}

static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if data.get("schema") != SCHEMA:
		errors.append("Unsupported scenario schema")
	if str(data.get("version", "")).is_empty():
		errors.append("Scenario version is required")
	for key in ["rooms", "actors", "connections", "commitments", "interactions"]:
		if not data.get(key) is Array:
			errors.append("Scenario %s must be an array" % key)
	if not errors.is_empty(): return errors
	var rooms := {}
	var room_data := {}
	var assets: Variant = data.get("assets", {})
	if not assets is Dictionary:
		errors.append("Project assets must be a manifest object")
		assets = {}
	for asset_id in assets:
		var problem := Assets.validate(assets[asset_id])
		if not problem.is_empty():
			errors.append("Asset %s: %s" % [asset_id, problem])
	for room in data.rooms:
		if not room is Dictionary:
			errors.append("Room entry must be an object")
			continue
		var id := str(room.get("id", ""))
		if id.is_empty() or rooms.has(id):
			errors.append("Room ID missing or duplicated: " + id)
		rooms[id] = true
		room_data[id] = room
		errors.append_array(Geometry.validate(room))
		var background_id := str(room.get("background_asset", ""))
		if not background_id.is_empty() and not assets.has(background_id):
			errors.append("Room %s references missing background asset %s" % [id, background_id])
	for required in ["service", "corridor"]:
		if not rooms.has(required): errors.append("Missing required room " + required)
	var actors := {}
	for actor in data.actors:
		if not actor is Dictionary:
			errors.append("Actor entry must be an object")
			continue
		var id := str(actor.get("id", ""))
		if id.is_empty() or actors.has(id):
			errors.append("Actor ID missing or duplicated: " + id)
		actors[id] = true
		if not rooms.has(actor.get("room", "")):
			errors.append("Actor %s has missing room %s" % [id, actor.get("room", "")])
		if not _number(actor.get("x")) or not _number(actor.get("y")):
			errors.append("Actor %s needs numeric x and y" % id)
		elif room_data.has(actor.get("room", "")) and Geometry.validate(room_data[actor.room]).is_empty() and not Geometry.contains(room_data[actor.room], Vector2(float(actor.x), float(actor.y))):
			errors.append("Actor %s starts outside walkable geometry" % id)
	for required in ["amelia", "chatterbox", "guest"]:
		if not actors.has(required): errors.append("Missing required actor " + required)
	var connections := {}
	for connection in data.connections:
		if not connection is Dictionary:
			errors.append("Connection entry must be an object")
			continue
		var id := str(connection.get("id", ""))
		if id.is_empty() or connections.has(id):
			errors.append("Connection ID missing or duplicated: " + id)
		connections[id] = true
		for key in ["from", "to"]:
			if not rooms.has(connection.get(key, "")):
				errors.append("Connection %s has missing %s room" % [id, key])
		if connection.get("from", "") == connection.get("to", ""):
			errors.append("Connection %s must join two different rooms" % id)
		if not str(connection.get("requires_flag", "")) in ["", "close_valve"]:
			errors.append("Connection %s has unsupported access condition" % id)
		if not _number(connection.get("from_x")) or not _number(connection.get("to_x")):
			errors.append("Connection %s needs numeric endpoints" % id)
		else:
			for side in ["from", "to"]:
				if not _number(connection.get(side + "_y", 160.0)):
					errors.append("Connection %s %s endpoint needs numeric y" % [id, side])
					continue
				var room_id := str(connection.get(side, ""))
				if room_data.has(room_id) and Geometry.validate(room_data[room_id]).is_empty():
					var point := Vector2(float(connection.get(side + "_x")), float(connection.get(side + "_y", 160.0)))
					if not Geometry.contains(room_data[room_id], point):
						errors.append("Connection %s %s endpoint is outside walkable geometry" % [id, side])
	if connections.is_empty(): errors.append("At least one room connection is required")
	var commitments := {}
	for commitment in data.commitments:
		if not commitment is Dictionary:
			errors.append("Commitment entry must be an object")
			continue
		var id := str(commitment.get("id", ""))
		if id.is_empty() or commitments.has(id):
			errors.append("Commitment ID missing or duplicated: " + id)
		commitments[id] = true
		if not actors.has(commitment.get("actor", "")):
			errors.append("Commitment %s has missing actor" % id)
		if not rooms.has(commitment.get("room", "")):
			errors.append("Commitment %s has missing room" % id)
		if not _number(commitment.get("at_tick")) or not _number(commitment.get("speed")) or not _number(commitment.get("x")):
			errors.append("Commitment %s needs numeric timing, speed and target" % id)
		elif int(commitment.at_tick) < 0 or float(commitment.speed) <= 0.0:
			errors.append("Commitment %s has invalid timing or speed" % id)
		elif room_data.has(commitment.get("room", "")) and Geometry.validate(room_data[commitment.room]).is_empty() and not Geometry.contains(room_data[commitment.room], Vector2(float(commitment.x), float(commitment.get("y", 160.0)))):
			errors.append("Commitment %s ends outside walkable geometry" % id)
	var interactions := {}
	for interaction in data.interactions:
		if not interaction is Dictionary:
			errors.append("Interaction entry must be an object")
			continue
		var id := str(interaction.get("id", ""))
		if id.is_empty() or interactions.has(id):
			errors.append("Interaction ID missing or duplicated: " + id)
		interactions[id] = true
		if not rooms.has(interaction.get("room", "")):
			errors.append("Interaction %s has missing room" % id)
		if not _number(interaction.get("x")) or not _number(interaction.get("y")) or not _number(interaction.get("radius")) or not _number(interaction.get("duration_ticks")):
			errors.append("Interaction %s needs numeric position, range and duration" % id)
		elif float(interaction.radius) <= 0.0 or int(interaction.duration_ticks) <= 0:
			errors.append("Interaction %s has invalid range or duration" % id)
		elif room_data.has(interaction.get("room", "")) and Geometry.validate(room_data[interaction.room]).is_empty() and not Geometry.contains(room_data[interaction.room], Vector2(float(interaction.x), float(interaction.y))):
			errors.append("Interaction %s is outside walkable geometry" % id)
		if not str(interaction.get("effect", "")) in ["close_valve", "delay_guest"]:
			errors.append("Interaction %s has unknown effect" % id)
		elif interaction.effect == "delay_guest" and (not _number(interaction.get("effect_ticks")) or int(interaction.effect_ticks) <= 0):
			errors.append("Interaction %s needs a positive guest delay in ticks" % id)
		if not interaction.get("label") is String or str(interaction.label).strip_edges().is_empty():
			errors.append("Interaction %s needs a visible label" % id)
	if errors.is_empty():
		var amelia: Dictionary = {}
		for actor in data.actors:
			if actor.id == "amelia":
				amelia = actor
				break
		for interaction in data.interactions:
			if not Geometry.reachable(data, str(amelia.room), Vector2(float(amelia.x), float(amelia.y)), str(interaction.room), Vector2(float(interaction.x), float(interaction.y))):
				errors.append("Interaction %s is unreachable from Amelia through authored walkable regions and room connections" % interaction.id)
	var actor_ids: Array[String] = []
	for id in actors: actor_ids.append(id)
	if not data.get("dialogue") is String:
		errors.append("Dialogue source must be text")
	else:
		var dialogue: Dictionary = Dialogue.parse(data.dialogue, actor_ids)
		errors.append_array(dialogue.errors)
	return errors

static func _number(value: Variant) -> bool:
	return value is int or value is float
