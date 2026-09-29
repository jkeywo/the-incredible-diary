extends RefCounted
## Dynamic resource names belong here; static preload/scene dependencies are
## discovered automatically by the web exporter. Future missions share the cache.
const Rooms = preload("res://mission1/rooms.gd")
const Sim = preload("res://mission1/simulation.gd")
const SKINS := {"amelia":"player","guest":"rake","chandelier_guest":"glamorous","chatterbox":"matron","crew":"sailor","porter":"ex_army","dock_sailor":"sailor","captain":"captain"}
const PROPS := {"docks":["suitcase","bag_hiding"],"foyer":["chandelier"],"controls":["code_panel","steam_vent"],"salon":["drink"],"cabins":["cabin_door"]}

static func room_paths(id: String) -> Array:
	var paths: Array = ["res://assets/rooms/mission_1/%s.tscn" % Rooms.ROOMS[id].scene]
	for prop in PROPS.get(id,[]): paths.append("res://assets/props/mission_1/%s.tscn" % prop)
	return paths

static func character_paths(id: String) -> Array:
	var skin: String = SKINS.get(id,Sim.Routines.INCIDENTAL_SKINS.get(id,""))
	if skin == "captain": return ["res://assets/characters/source/captain.png"]
	if skin in ["sailor","guest_male_jacket","guest_male_waistcoat","guest_female_dress","guest_female_coat"]:
		var paths: Array = ["res://assets/characters/generic/%s_sprites.png" % skin,"res://assets/characters/generic/%s_sprites_mask.png" % skin]
		if skin == "sailor": paths.append_array(["res://assets/characters/actions/sailor_actions.png","res://assets/characters/actions/sailor_actions_mask.png"])
		return paths
	var paths: Array = ["res://assets/characters/%s_sprites.png" % skin]
	if skin == "player": paths.append_array(["res://assets/characters/player_walk.png","res://assets/characters/actions/amelia_actions.png"])
	if skin in ["rake","matron","glamorous"]: paths.append("res://assets/characters/actions/%s_actions.png" % skin)
	if skin == "rake": paths.append("res://assets/characters/rake_stained_sprites.png")
	if skin == "matron": paths.append("res://assets/characters/actions/matron_steam_casualty.png")
	return paths

static func for_state(state: Dictionary) -> Array:
	var paths := room_paths(str(state.room))
	paths.append_array(character_paths("amelia"))
	for id in state.get("actors",{}):
		if state.actors[id].room == state.room: paths.append_array(character_paths(id))
	return paths

static func neighbours(id: String) -> Array:
	var paths: Array = []
	for door in Rooms.DOORS:
		if door.a == id: paths.append_array(room_paths(door.b))
		elif door.b == id: paths.append_array(room_paths(door.a))
	return paths
