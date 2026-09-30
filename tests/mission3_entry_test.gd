extends SceneTree
const Title = preload("res://assets/ui/mission_1/title_screen.tscn")
const Sim = preload("res://mission1/simulation.gd")
const Save = preload("res://mission1/save.gd")
const PATH := "res://build/mission3-entry.journal"

func _initialize() -> void: call_deferred("checks")

func checks() -> void:
	Save.clear(PATH)
	var run := Sim.new(false)
	run.start_mission_three()
	run.s.room = "market"
	run.s.pos = [600,550]
	run.record_current_frame()
	assert(Save.new().save_run(run,PATH).ok)
	for next_page in [false,true]:
		if next_page: set_meta("open_mission3",true)
		var title = Title.instantiate()
		title.mission_save_path = "res://build/mission3-unused.journal"
		title.mission_three_save_path = PATH
		root.add_child(title)
		current_scene = title
		assert(title.dev_choices.size() == 4)
		assert(title.dev_choices[2].text.begins_with("Mission 3"))
		if not next_page: title._on_mission_three()
		await process_frame
		await process_frame
		assert(title._pending_saved.current.room == ("passage" if next_page else "market"))
		if next_page: assert(title._pending_saved.current.pos == [205,275])
		assert(title._pending_saved.authored_content.settings.mission == 3)
		assert(not has_meta("open_mission3"))
		if is_instance_valid(title._game_world): title._game_world.save_enabled = false
		title.queue_free()
		await process_frame
	Save.clear(PATH)
	print("MISSION3 ENTRY PASS: dev menu resumes Greece; next page starts in player's cabin")
	await preload("res://tests/shutdown.gd").finish(self)
