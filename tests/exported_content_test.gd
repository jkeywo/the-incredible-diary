extends SceneTree
## Run against ONLY the exported bootstrap pack, from the build/web directory.
const Plan = preload("res://mission1/content_plan.gd")
func _initialize() -> void:
	call_deferred("checks")
func checks() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("../web-content-manifest.json"))
	assert(load("res://assets/ui/mission_1/title_screen.tscn") != null)
	var mounted := {}
	var paths: Array = ["res://mission1/play.tscn"]
	for room in Plan.Rooms.ROOMS: paths.append_array(Plan.room_paths(room))
	var second := preload("res://mission2/content.gd").seed()
	for room in second.rooms: paths.append_array(Plan.room_paths(room,second))
	for id in Plan.SKINS: paths.append_array(Plan.character_paths(id))
	for id in Plan.Sim.Routines.INCIDENTAL_SKINS: paths.append_array(Plan.character_paths(id))
	for path in paths:
		assert(manifest.resources.has(path),"Missing manifest entry: "+path)
		for hash in manifest.resources[path]:
			if mounted.has(hash): continue
			assert(ProjectSettings.load_resource_pack(str(manifest.packs[hash].url),false))
			mounted[hash] = true
		assert(load(path) != null,"Missing exported resource: "+path)
	print("EXPORTED CONTENT PASS: bootstrap, every room, character and shared dependency")
	quit()
