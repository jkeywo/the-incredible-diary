extends SceneTree
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
	game.sim.s.actors.chatterbox = {"room":"salon","pos":[740,400],"action":"idle","facing":"down"}
	game._refresh()
	for i in 1000:
		if game._prepare_visible(game.sim.s): break
		await process_frame
	game._refresh()
	assert(game.actors.chatterbox.visible)
	title.queue_free()
	await process_frame
	Save.clear(PATH)
	print("LEVEL LOADING PASS: early click, failure preserves save, retry, swipe, room wait, unchanged history and cache reuse")
	quit()
