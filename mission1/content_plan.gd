extends RefCounted
## Dynamic resource names belong here; static preload/scene dependencies are
## discovered automatically by the web exporter. Future missions share the cache.
const Rooms = preload("res://mission1/rooms.gd")
const Sim = preload("res://mission1/simulation.gd")
const SKINS := {"amelia":"player","guest":"rake","chandelier_guest":"glamorous","chatterbox":"matron","crew":"sailor","porter":"ex_army","dock_sailor":"sailor","captain":"captain"}
const PROPS := {"docks":["suitcase","bag_hiding"],"foyer":["chandelier"],"controls":["code_panel","steam_vent"],"salon":["drink"],"cabins":["cabin_door"]}

static func room_paths(id: String, content: Dictionary = {}) -> Array:
	if not content.is_empty():
		var result: Array = []
		var room: Dictionary = content.rooms.get(id,{})
		if not str(room.get("scene", "")).is_empty(): result.append("res://assets/rooms/mission_1/%s.tscn" % room.scene)
		for entity_id in content.instances:
			var entity := preload("res://mission1/authoring_content.gd").resolve(content,entity_id)
			if entity.kind != "character" and entity.room == id: result.append("res://assets/props/mission_1/%s.tscn" % entity.appearance)
		return result
	var paths: Array = ["res://assets/rooms/mission_1/%s.tscn" % Rooms.ROOMS[id].scene]
	for prop in PROPS.get(id,[]): paths.append("res://assets/props/mission_1/%s.tscn" % prop)
	return paths

static func skin_for(id: String) -> String:
	return SKINS.get(id,Sim.Routines.INCIDENTAL_SKINS.get(id,Sim.Departure.skin(id)))

static func character_paths(id: String, appearance := "") -> Array:
	var skin: String = appearance if not appearance.is_empty() else skin_for(id)
	if skin == "captain": return ["res://assets/characters/source/captain.png"]
	if skin in ["sailor","guest_male_jacket","guest_male_waistcoat","guest_female_dress","guest_female_coat"]:
		var paths: Array = ["res://assets/characters/generic/%s_sprites.png" % skin,"res://assets/characters/generic/%s_sprites_mask.png" % skin]
		if skin == "sailor": paths.append_array(["res://assets/characters/actions/sailor_actions.png","res://assets/characters/actions/sailor_actions_mask.png"])
		else: paths.append_array(["res://assets/characters/generic/%s_wave.png" % skin,"res://assets/characters/generic/%s_wave_mask.png" % skin])
		return paths
	var paths: Array = ["res://assets/characters/%s_sprites.png" % skin]
	if skin == "player": paths.append_array(["res://assets/characters/player_walk.png","res://assets/characters/actions/amelia_actions.png"])
	if skin in ["rake","matron","glamorous"]: paths.append("res://assets/characters/actions/%s_actions.png" % skin)
	if skin == "rake": paths.append("res://assets/characters/rake_stained_sprites.png")
	if skin == "matron": paths.append("res://assets/characters/actions/matron_steam_casualty.png")
	return paths

static func for_state(state: Dictionary, content: Dictionary = {}) -> Array:
	return room_paths(str(state.room),content)

static func level_characters() -> Array:
	var paths: Array = []
	for id in SKINS.keys() + Sim.Routines.INCIDENTAL_SKINS.keys():
		for path in character_paths(id):
			if not paths.has(path): paths.append(path)
	return paths

static func neighbours(id: String, content: Dictionary = {}) -> Array:
	var paths: Array = []
	for door in content.get("connections",Rooms.DOORS):
		if door.a == id: paths.append_array(room_paths(door.b,content))
		elif door.b == id: paths.append_array(room_paths(door.a,content))
	return paths
