extends RefCounted
## Portable Mission 1 definitions. Never contains a live Node or simulation snapshot.
const Grid = preload("res://mission1/authoring_grid.gd")
const Rooms = preload("res://mission1/rooms.gd")
const Assets = preload("res://foundation/project_assets.gd")
const Dialogue = preload("res://foundation/dialogue.gd")
const SKINS := {"amelia":"player", "guest":"rake", "chandelier_guest":"glamorous", "chatterbox":"matron", "crew":"sailor", "porter":"ex_army", "dock_sailor":"sailor", "captain":"captain"}

static func seed(actors: Dictionary) -> Dictionary:
	var data := {"kind":"mission1", "schema":1, "version":"mission1-layout-6", "dialogue":"", "assets":{}, "scenes":{}, "storylets":[], "actors":[], "rooms":{}, "templates":{}, "instances":{}, "schedules":{}, "connections":Rooms.DOORS.duplicate(true), "settings":{"cell_size":25}, "timings":{"creak":4080, "fall":4160, "trap":5500, "steam_fatal":6000, "poison":7650, "end":8100, "demo_start":1850, "demo_end":2300}}
	data.scenes = preload("res://mission1/authoring_dialogues.gd").SCENES.duplicate(true)
	data.texts = preload("res://mission1/authoring_dialogues.gd").TEXTS.duplicate(true)
	for index in data.connections.size():
		var connection: Dictionary = data.connections[index]
		connection.id = "connection_" + str(index + 1)
		for side in ["a","b"]:
			var point := Rooms.point(connection[side + "p"])
			var bounds := Rooms.exit_bounds(connection[side],point)
			connection[side + "_bounds"] = [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
			connection[side + "_arrival"] = Rooms.arrival_point(connection[side],point)
	for id in Rooms.ROOMS:
		var original: Dictionary = Rooms.ROOMS[id]
		data.rooms[id] = {"title":original.title, "scene":original.scene, "background_asset":"", "size":[1175,700], "blocked":Grid.migrate(original.floor)}
	data.rooms.passage.floor_regions = Rooms.ROOMS.passage.floor.duplicate(true)
	data.rooms.cabins.origin = [-50,0]
	for y in range(17,25):
		for x in [-2,-1]: data.rooms.cabins.blocked.erase(Grid.key(Vector2i(x,y)))
	for kind in ["character", "prop", "door", "interaction"]:
		data.templates[kind] = {"kind":kind, "name":kind.capitalize(), "appearance":"player" if kind == "character" else "suitcase", "initial_state":"idle", "states":{"idle":{"visible":true, "solid":false}}, "transitions":[], "interactions":[]}
	var roster := actors.duplicate(true)
	roster.amelia = {"room":"docks", "pos":[580,490]}
	for id in SKINS:
		if not roster.has(id): roster[id] = {"room":"docks", "pos":[650,280] if id == "captain" else [720,440]}
	for id in ["incidental_sailor_1","incidental_sailor_2","incidental_sailor_3","incidental_guest_1","incidental_guest_2","incidental_guest_3","incidental_guest_4"]:
		if not roster.has(id): roster[id] = {"room":"cabins","pos":[-25,530]}
	for id in roster:
		var template: Dictionary = data.templates.character.duplicate(true)
		template.name = {"amelia":"Boy","guest":"Mr. Felix Harcourt","chandelier_guest":"Miss Evelyn Vale","chatterbox":"Mrs. Mabel Pritchard","crew":"Sailor","dock_sailor":"Sailor","captain":"Captain","porter":"Porter"}.get(id,"Sailor" if str(id).contains("sailor") else "Guest" if str(id).begins_with("incidental") else str(id).capitalize())
		template.appearance = SKINS.get(id, {"incidental_guest_1":"guest_male_jacket","incidental_guest_2":"guest_female_dress","incidental_guest_3":"guest_female_coat","incidental_guest_4":"guest_male_waistcoat"}.get(id,"sailor"))
		if str(id).begins_with("sendoff_guest_"):
			template.name = "Guest"
			template.appearance = preload("res://mission1/departure.gd").skin(id)
		data.templates[id] = template
		data.instances[id] = {"template":str(id), "room":roster[id].room, "position":roster[id].pos.duplicate(), "overrides":{}, "builtin":true}
		data.actors.append({"id":id})
		data.schedules[id] = {"mode":"mission", "commitments":[]}
	var routes := {
		"chandelier_guest":{"origin":[720,440],"action":"talk","facing":"right","stages":[[160,"cabins",[225,315],"idle"],[850,"foyer",[495,365],"talk","left"],[1450,"salon",[735,345],"talk","right"],[2600,"cabins",[225,315],"idle"],[3500,"foyer",[580,412],"idle"]]},
		"chatterbox":{"origin":[765,440],"action":"talk","facing":"left","stages":[[320,"cabins",[935,315],"idle"],[980,"cabins",[700,530],"talk","right"],[1500,"salon",[780,345],"talk","left"],[2600,"cabins",[935,315],"idle"],[{"arrive":5400,"from_room":"cabins","from":[935,315],"margin":60},"controls",[840,360],"idle"]]},
		"crew":{"origin":[640,430],"action":"idle","facing":"down","stages":[[60,"controls",[310,305],"idle"]]},
		"porter":{"origin":[670,475],"action":"idle","facing":"down","stages":[[460,"foyer",[450,365],"idle"]]}
	}
	for id in routes:
		data.schedules[id].merge(routes[id])
	var props := {"suitcase":["docks",[145,390],"suitcase","present","bag_found"], "bag_hiding":["docks",[210,335],"bag_hiding","empty","bag_hidden"], "chandelier":["foyer",[580,380],"chandelier","idle","chandelier_fallen"], "code_panel":["controls",[350,280],"code_panel","entry","steam_off"], "steam_vent":["controls",[940,290],"steam_vent","off","trapped"], "drink":["salon",[930,132],"drink","idle","spilled"]}
	for id in Rooms.CABIN_DOORS: props[id] = ["cabins",[Rooms.CABIN_DOORS[id],427],"cabin_door","closed",id]
	for id in props:
		var spec: Array = props[id]
		var template: Dictionary = data.templates.prop.duplicate(true)
		template.name = str(id).capitalize()
		template.appearance = spec[2]
		template.initial_state = spec[3]
		template.states = {spec[3]:{"visible":true,"solid":false}, "changed":{"visible":id != "suitcase","solid":false}}
		template.transitions = [{"state":"changed", "conditions":[{"flag":spec[4],"equals":true}]}]
		data.templates[id] = template
		data.instances[id] = {"template":str(id),"room":spec[0],"position":spec[1],"overrides":{},"builtin":true}
	var states := {"suitcase":["present","hidden"], "bag_hiding":["empty","occupied"], "chandelier":["intact","warning","fallen"], "code_panel":["standby","entry","accepted","rejected"], "steam_vent":["off","active"], "drink":["full","spiked","spilled","empty"]}
	for id in Rooms.CABIN_DOORS: states[id] = ["closed","open"]
	for id in states:
		var template: Dictionary = data.templates[id]
		template.initial_state = states[id][0]
		template.states = {}
		for state in states[id]: template.states[state] = {"appearance":state,"visible":true,"solid":false}
		template.transitions = [{"state":states[id][0],"conditions":[]}]
		var flag_states: Dictionary = {"suitcase":{"bag_hidden":"hidden"},"bag_hiding":{"bag_hidden":"occupied"},"chandelier":{"chandelier_warning":"warning","chandelier_fallen":"fallen"},"code_panel":{"steam_off":"accepted","panel_rejected":"rejected"},"steam_vent":{"trapped":"active","steam_off":"off"},"drink":{"spiked":"spiked","spilled":"spilled"}}.get(id,{id:"open"})
		for flag in flag_states: template.transitions.append({"state":flag_states[flag],"conditions":[{"flag":flag,"equals":true}]})
	for id in Rooms.CABIN_DOORS: data.templates[id].states.closed.merge({"solid":true,"bounds":[-48,-57,96,70]})
	data.templates.chandelier.states.fallen.merge({"solid":true,"bounds":[-60,-55,120,65]})
	data.templates.steam_vent.states.active.merge({"solid":true,"bounds":[30,-50,110,100]},true)
	data.templates.suitcase.states.absent = {"appearance":"present","visible":false,"solid":false}
	data.templates.suitcase.transitions.append({"state":"absent","conditions":[{"flag":"bag_found","equals":true}]})
	data.templates.drink.states.unserved = {"appearance":"full","visible":false,"solid":false}
	data.templates.drink.transitions[0].state = "unserved"
	data.templates.drink.transitions.insert(1,{"state":"full","conditions":[{"flag":"party_arrived","equals":true}]})
	data.templates.drink.transitions.append({"state":"empty","conditions":[{"dead":"guest","equals":true}]})
	data.templates.prop.states.idle.appearance = "present"
	data.templates.door.appearance = "cabin_door"
	data.templates.door.states.idle.appearance = "closed"
	data.templates.interaction.states.idle.appearance = "present"
	var rules := [["luggage_routine",0,10800,[]], ["party_routine",0,10800,[]], ["steam_trap",5500,5500,[]], ["steam_fatal",6000,6000,[{"safe":"chatterbox","equals":false}]], ["steam_alarm",6030,6030,[{"dead":"chatterbox","equals":true}]], ["chandelier_warning",4080,4080,[]], ["chandelier_drop",4148,4148,[{"has_flag":"chandelier_drop_tick","equals":false}]], ["chandelier_impact",4160,10800,[{"flag":"chandelier_fallen","equals":false}]]]
	for index in rules.size():
		var rule: Array = rules[index]
		data.storylets.append({"id":rule[0],"phase":"schedule","start_tick":rule[1],"end_tick":rule[2],"conditions":rule[3],"participants":[],"priority":100-index,"repeat":index < 2,"scene":"","effects":[{"command":"mission","operation":rule[0]}]})
	var conversations := [
		["nephew",["guest","chatterbox"],"",[{"flag":"chat_delay","equals":true}]],
		["steam_help",["chatterbox"],"controls",[{"flag":"trapped","equals":true},{"safe":"chatterbox","equals":false},{"dead":"chatterbox","equals":false}]],
		["bags",["guest","dock_sailor"],"docks",[{"flag":"bag_found","equals":false},{"actor":"dock_sailor","field":"action","equals":"talk"}]],
		["bags_waiting",["guest"],"docks",[{"flag":"bag_found","equals":false},{"distance":["amelia","guest"],"maximum":110}]],
		["directions",["chandelier_guest","porter"],"",[{"actor":"chandelier_guest","field":"action","equals":"talk"},{"distance":["chandelier_guest","porter"],"maximum":100}]],
		["weather",["chandelier_guest","chatterbox"],"",[{"actor":"chandelier_guest","field":"action","equals":"talk"},{"distance":["chandelier_guest","chatterbox"],"maximum":100}]],
		["cabins",["chatterbox","guest"],"",[{"actor":"chatterbox","field":"action","equals":"talk"},{"distance":["chatterbox","guest"],"maximum":100}]]
	]
	for index in conversations.size():
		var rule: Array = conversations[index]
		data.storylets.append({"id":"conversation_"+rule[0],"phase":"conversation","room":rule[2],"start_tick":0,"end_tick":10800,"conditions":rule[3],"participants":rule[1],"priority":100-index,"repeat":false,"scene":rule[0],"effects":[]})
	return data

static func resolve(data: Dictionary, id: String) -> Dictionary:
	if not data.get("instances", {}).has(id): return {}
	var instance: Dictionary = data.instances[id]
	var result: Dictionary = data.templates.get(instance.get("template", ""), {}).duplicate(true)
	result.merge(instance.get("overrides", {}), true)
	result.merge({"id":id, "room":instance.room, "position":instance.position}, true)
	return result

static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if data.get("schema") != 1: return ["Unsupported Mission 1 content schema"]
	for field in ["rooms", "templates", "instances", "schedules", "assets", "scenes", "timings"]:
		if not data.get(field) is Dictionary: errors.append("%s must be an object" % field)
	for field in ["actors", "connections", "storylets"]:
		if not data.get(field) is Array: errors.append("%s must be a list" % field)
	if not errors.is_empty(): return errors
	if not data.instances.has("amelia"): errors.append("The player entity amelia is required")
	for id in SKINS:
		if not data.instances.has(id): errors.append("Mission 1 operations still reference character " + str(id))
	for id in data.rooms:
		var room: Variant = data.rooms[id]
		if not room is Dictionary or not room.get("blocked") is Dictionary or not _point(room.get("size")):
			errors.append("Room %s needs dimensions and collision cells" % id)
			continue
		if room.size[0] <= 0 or room.size[1] <= 0 or room.size[0] > 10000 or room.size[1] > 10000: errors.append("Room %s dimensions must be 1–10000" % id)
		for cell in room.blocked:
			var parts := str(cell).split(",")
			if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or room.blocked[cell] != true: errors.append("Room %s collision cells must use integer x,y keys and true values" % id)
		if not str(room.get("background_asset", "")).is_empty() and not data.assets.has(room.background_asset): errors.append("Room %s background asset is missing" % id)
	for id in data.templates:
		var template: Variant = data.templates[id]
		if not template is Dictionary or template.get("kind") not in ["character","prop","door","interaction"]:
			errors.append("Template %s has an invalid entity kind" % id)
			continue
		if not template.get("states", {}) is Dictionary or not template.get("transitions", []) is Array or not template.get("interactions", []) is Array: errors.append("Template %s has invalid state rules" % id)
	if not errors.is_empty(): return errors
	for id in data.templates:
		var template: Dictionary = data.templates[id]
		for state in template.get("states",{}).values():
			if not state is Dictionary: errors.append("Template %s states must be objects" % id)
		for transition in template.get("transitions",[]):
			if not transition is Dictionary or not template.get("states",{}).has(transition.get("state","")) or not transition.get("conditions",[]) is Array: errors.append("Template %s has an invalid transition" % id)
	if not errors.is_empty(): return errors
	for id in data.instances:
		var item: Variant = data.instances[id]
		if not item is Dictionary or not _point(item.get("position")) or not item.get("overrides") is Dictionary or not item.get("room") is String or not item.get("template") is String:
			errors.append("Entity %s needs a position and overrides" % id)
			continue
		if not data.templates.has(item.get("template", "")): errors.append("Entity %s template is missing" % id)
		if not data.rooms.has(item.get("room", "")): errors.append("Entity %s room is missing" % id)
		var entity := resolve(data,id)
		var appearances: Array = SKINS.values() + ["guest_male_jacket","guest_male_waistcoat","guest_female_dress","guest_female_coat"] if entity.get("kind") == "character" else ["suitcase","bag_hiding","chandelier","code_panel","steam_vent","drink","cabin_door","crew_door","janitor","service_door","valve"]
		if not appearances.has(entity.get("appearance")): errors.append("Entity %s has an unknown appearance" % id)
		if not entity.get("states",{}) is Dictionary or not entity.get("transitions",[]) is Array:
			errors.append("Entity %s state overrides are invalid" % id)
			continue
		for transition in entity.get("transitions",[]):
			if not transition is Dictionary or not entity.get("states",{}).has(transition.get("state","")):
				errors.append("Entity %s transition target is missing" % id)
				continue
			errors.append_array(validate_conditions(transition.get("conditions",[]),data))
		if not entity.get("interactions",[]) is Array:
			errors.append("Entity %s interactions must be a list" % id)
			continue
		for interaction in entity.get("interactions",[]):
			if not interaction is Dictionary or not _point(interaction.get("position",item.position)):
				errors.append("Entity %s has an invalid interaction position" % id)
				continue
			var position: Array = interaction.get("position",item.position)
			errors.append_array(validate_conditions(interaction.get("conditions",[]),data))
			errors.append_array(validate_effects(interaction.get("effects",[]),data))
			if not _number(interaction.get("duration",10)) or interaction.get("duration",10) <= 0: errors.append("Interaction duration must be positive")
			if data.rooms.has(item.room) and data.rooms[item.room].get("blocked") is Dictionary and not Grid.contains(data.rooms[item.room],Vector2(position[0],position[1])): errors.append("Entity %s interaction is blocked by authored collision" % id)
	for connection in data.connections:
		if not connection is Dictionary or not data.rooms.has(connection.get("a", "")) or not data.rooms.has(connection.get("b", "")) or not _point(connection.get("ap")) or not _point(connection.get("bp")):
			errors.append("A room connection has missing endpoints")
		else:
			for side in ["a","b"]:
				var room: Dictionary = data.rooms[connection[side]]
				var position: Array = connection[side + "p"]
				if room.get("blocked") is Dictionary and not Grid.contains(room,Vector2(position[0],position[1])): errors.append("Connection endpoint in %s is blocked" % connection[side])
	for id in data.schedules:
		if not data.instances.has(id): errors.append("Schedule %s actor is missing" % id)
		var schedule: Variant = data.schedules[id]
		if not schedule is Dictionary or not schedule.get("commitments") is Array:
			errors.append("Schedule %s needs commitments" % id)
			continue
		for commitment in schedule.commitments:
			if not commitment is Dictionary or not _number(commitment.get("tick")) or not data.rooms.has(commitment.get("room", "")) or not _point(commitment.get("position")):
				errors.append("Schedule %s has an invalid commitment" % id)
		if schedule.has("stages"):
			if not _point(schedule.get("origin")) or not schedule.stages is Array: errors.append("Schedule %s needs an origin and stages" % id)
			else:
				for stage in schedule.stages:
					if not stage is Array or stage.size() < 4 or not data.rooms.has(stage[1]) or not _point(stage[2]): errors.append("Schedule %s has an invalid stage" % id)
	if not errors.is_empty(): return errors
	for story in data.storylets:
		if not story is Dictionary or not story.get("id") is String or not story.get("conditions", []) is Array or not story.get("effects", []) is Array:
			errors.append("Storylet needs an ID, conditions and effects")
			continue
		if not _number(story.get("start_tick",0)) or not _number(story.get("end_tick",10800)) or not _number(story.get("priority",0)) or not story.get("participants",[]) is Array:
			errors.append("Storylet %s has invalid timing or participants" % story.id)
			continue
		if not str(story.get("scene", "")).is_empty() and not data.scenes.has(story.scene): errors.append("Storylet %s scene is missing" % story.id)
		for actor in story.get("participants", []):
			if not data.instances.has(actor): errors.append("Storylet %s actor %s is missing" % [story.id, actor])
		for effect in story.get("effects", []):
			if not effect is Dictionary or effect.get("command") not in ["flag", "prop", "say", "note", "mission"]: errors.append("Storylet %s has an unsupported command" % story.id)
			elif effect.command == "mission" and effect.get("operation") not in ["luggage_routine","party_routine","steam_trap","steam_fatal","steam_alarm","chandelier_warning","chandelier_drop","chandelier_impact"]: errors.append("Unsupported Mission 1 operation")
			elif effect.command == "flag" and not effect.get("key") is String: errors.append("Flag command needs a key")
			elif effect.command == "prop" and (not data.instances.has(effect.get("entity","")) or not effect.get("state") is String): errors.append("Prop command needs an entity and state")
			elif effect.command == "say" and (not data.instances.has(effect.get("actor","")) or not effect.get("text") is String): errors.append("Say command needs an actor and text")
			elif effect.command == "note" and (not effect.get("key") is String or not effect.get("text") is String): errors.append("Note command needs a key and text")
		for condition in story.get("conditions",[]):
			if not condition is Dictionary: errors.append("Storylet conditions must be objects")
		errors.append_array(validate_conditions(story.get("conditions",[]),data))
		errors.append_array(validate_effects(story.get("effects",[]),data))
	for id in data.timings:
		if not _number(data.timings[id]) or data.timings[id] < 0 or data.timings[id] > 10800: errors.append("Timing %s must be within the leg" % id)
	for id in data.assets:
		var reason := Assets.validate(data.assets[id])
		if not reason.is_empty(): errors.append("Asset %s: %s" % [id, reason])
	var actor_ids: Array[String] = []
	for id in data.instances: actor_ids.append(str(id))
	for id in data.scenes:
		if not data.scenes[id] is String: errors.append("Scene %s must be source text" % id)
		else: errors.append_array(Dialogue.parse(data.scenes[id], actor_ids).errors)
	if not errors.is_empty(): return errors
	var player: Dictionary = data.instances.amelia
	for id in data.instances:
		var entity := resolve(data,id)
		for interaction in entity.get("interactions",[]):
			var point: Array = interaction.get("position",entity.position)
			if not reachable(data,player.room,player.position,entity.room,point): errors.append("Entity %s interaction has no route from the player start" % id)
	for id in data.schedules:
		var start: Dictionary = data.instances[id]
		for commitment in data.schedules[id].commitments:
			if not reachable(data,start.room,start.position,commitment.room,commitment.position): errors.append("Schedule %s destination has no connected route" % id)
	return errors

static func reachable(data: Dictionary, origin_room: String, origin: Array, target_room: String, target: Array) -> bool:
	var pending := [{"room":origin_room,"point":origin}]
	var visited := {}
	while not pending.is_empty():
		var entry: Dictionary = pending.pop_front()
		var key := str(entry.room)+str(entry.point)
		if visited.has(key): continue
		visited[key] = true
		var room: Dictionary = data.rooms[entry.room]
		if entry.room == target_room and not Grid.path(room,Rooms.point(entry.point),Rooms.point(target)).is_empty(): return true
		for connection in data.connections:
			for side in ["a","b"]:
				if connection[side] != entry.room: continue
				if Grid.path(room,Rooms.point(entry.point),Rooms.point(connection[side+"p"])).is_empty(): continue
				var other := "b" if side == "a" else "a"
				pending.append({"room":connection[other],"point":connection[other+"p"]})
	return false

static func validate_conditions(items: Variant, data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not items is Array: return ["Conditions must be a list"]
	for item in items:
		if not item is Dictionary: errors.append("Condition must be an object"); continue
		var known := false
		for key in ["flag","has_flag","actor","prop","safe","dead","distance"]:
			if item.has(key): known = true
		if not known: errors.append("Unknown condition; use flag, has_flag, actor, prop, safe, dead or distance")
		for key in ["actor","prop","safe","dead"]:
			if item.has(key) and not data.instances.has(item[key]): errors.append("Condition references missing entity " + str(item[key]))
		if item.has("distance"):
			if not item.distance is Array or item.distance.size() != 2 or not data.instances.has(item.distance[0]) or not data.instances.has(item.distance[1]) or not _number(item.get("maximum")): errors.append("Distance condition needs two entities and a maximum distance")
	return errors

static func validate_effects(items: Variant, data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not items is Array: return ["Effects must be a list"]
	for item in items:
		if not item is Dictionary: errors.append("Effect must be an object"); continue
		match item.get("command"):
			"flag":
				if not item.get("key") is String: errors.append("Flag effect needs a key")
			"prop":
				if not data.instances.has(item.get("entity","")) or not item.get("state") is String: errors.append("Prop effect needs an entity and state")
				elif not resolve(data,item.entity).get("states",{}).has(item.state): errors.append("Prop effect references an unknown state")
			"say":
				if not data.instances.has(item.get("actor","")) or not item.get("text") is String: errors.append("Say effect needs an actor and text")
			"note":
				if not item.get("key") is String or not item.get("text") is String: errors.append("Note effect needs a key and text")
			"mission":
				if item.get("operation") not in ["luggage_routine","party_routine","steam_trap","steam_fatal","steam_alarm","chandelier_warning","chandelier_drop","chandelier_impact"]: errors.append("Unknown Mission 1 operation")
			_: errors.append("Unknown effect command")
	return errors

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1])
