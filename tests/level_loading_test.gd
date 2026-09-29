extends SceneTree
const Play = preload("res://mission1/play.gd")
const Title = preload("res://assets/ui/mission_1/title_screen.tscn")
const Save = preload("res://mission1/save.gd")
const Sim = preload("res://mission1/simulation.gd")
const Plan = preload("res://mission1/content_plan.gd")
const PATH := "res://build/loading-save.journal"
func _initialize() -> void: call_deferred("checks")
func checks() -> void:
	Save.clear(PATH)
	var run := Sim.new(false)
	run.s.room = "salon"
	assert(Save.new().save_run(run,PATH).ok)
	var before := FileAccess.get_file_as_string(PATH)
	var title := Title.instantiate()
	title.mission_save_path = PATH
	root.add_child(title)
	current_scene = title
	assert(title._menu_audio.get_child_count() == 0)
	# Click before the deferred background request gets a frame.
	title._start_new()
	assert(title._waiting and is_instance_valid(title.loading_diary))
	assert(FileAccess.get_file_as_string(PATH) == before)
	var overlay = title.loading_diary
	title._on_continue()
	title._start_new()
	assert(title.loading_diary == overlay)
	title._level_failed("Test interruption")
	assert(not title._waiting and title.menu.visible)
	assert(FileAccess.get_file_as_string(PATH) == before)
	title.error_dialog.hide()
	title.error_motion.finish()
	title._start_new()
	for i in 1000:
		if is_instance_valid(title._game_world): break
		await process_frame
	assert(is_instance_valid(title._game_world))
	assert(not title._game_world.controls_enabled)
	await create_timer(1.9).timeout
	assert(title._game_world.controls_enabled)
	var game = title._game_world
	game.set_physics_process(false)
	game.sim.s.room = "salon"
	game.sim.record_current_frame()
	var history := JSON.stringify(game.sim.history)
	game._refresh()
	for i in 1000:
		if game._prepare_visible(game.sim.s): break
		await process_frame
	game._refresh()
	assert(game.shown_room == "salon")
	assert(JSON.stringify(game.sim.history) == history)
	assert(not Plan.neighbours("docks").any(func(path): return "05_party_salon" in path))
	var stream := root.get_node("ResourceStream")
	var cached: Dictionary = stream.request_resources(Plan.for_state(game.sim.s),true)
	assert(cached.done and cached.error.is_empty())
	assert(not game.actors.has("chatterbox")) # Offscreen character art is not instantiated.
	# Hold a character's art back even after the screen is ready. Arrival must
	# retain a position-only actor, without a modal or a stopped simulation.
	stream.set_process(false)
	for path in Plan.character_paths("chatterbox"): stream.resources.erase(path)
	game.sim.s.actors.chatterbox = {"room":"salon","pos":[740,400],"action":"idle","facing":"down"}
	game._refresh()
	assert(game.actors.chatterbox is Play.PendingCharacter)
	assert(game.actors.chatterbox.self_modulate.a == 0.0)
	assert(game._prepare_visible(game.sim.s) and not is_instance_valid(game._content_overlay))
	game.sim.s.tutorial = "done"
	var frame_before: int = game.sim.s.frame
	game._physics_process(0.11)
	assert(game.sim.s.frame > frame_before)
	game.sim.s.actors.chatterbox = {"room":"salon","pos":[740,400],"action":"idle","facing":"down"}
	var character_state := JSON.stringify(game.sim.s)
	stream.request_resources(Plan.character_paths("chatterbox"),false,2)
	stream.set_process(true)
	for i in 1000:
		if Plan.character_paths("chatterbox").all(func(path): return stream.resources.has(path)): break
		await process_frame
	game._refresh()
	assert(game.actors.chatterbox.visible)
	assert(not game.actors.chatterbox is Play.PendingCharacter)
	assert(JSON.stringify(game.sim.s) == character_state)
	# Screen priority wins even when character work was queued first.
	var scheduler = load("res://assets/ui/loading/resource_stream.gd").new()
	root.add_child(scheduler)
	scheduler.set_process(false)
	scheduler.request_resources(Plan.character_paths("chatterbox"),false,2)
	scheduler.request_resources(Plan.room_paths("foyer"))
	scheduler._process(0.0)
	assert(scheduler.active_resource == Plan.room_paths("foyer")[0])
	scheduler.queue_free()
	title.queue_free()
	await process_frame
	Save.clear(PATH)
	print("LEVEL LOADING PASS: screen priority, invisible character fallback without pausing, save preservation, room wait and cache reuse")
	quit()
