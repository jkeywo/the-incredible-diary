extends SceneTree
const Play = preload("res://mission1/play.tscn")
const Sim = preload("res://mission1/simulation.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func run() -> void:
	var game := Play.instantiate()
	game.sim = Sim.new(false)
	game.configure({},false)
	root.add_child(game)
	current_scene = game
	await process_frame
	game.toggle_pause_editor()
	await process_frame
	var editor = game.authoring_editor
	check(paused and editor.overlay.visible,"Mission 1 opens authored editor")
	check(editor.scrubber.get_global_rect().position.y > editor.workspace.get_global_rect().end.y,"Timeline has reserved bottom space")
	var recorded: Array = game.sim.history.duplicate(true)
	editor.placement_template = "prop"
	editor.tool = "Place"
	editor.map_click(Vector2(500,500))
	var id: String = editor.selected_id
	check(editor.document.content.instances.has(id),"Palette places a document instance")
	check(game.sim.history == recorded,"Placement never edits recorded world")
	check(editor.tool == "Select" and editor.placement_template.is_empty(),"Placement returns to selection")
	var placed_count: int = editor.document.content.instances.size()
	editor.map_click(Vector2(500,500))
	check(editor.document.content.instances.size() == placed_count,"Next click selects without adding a duplicate")
	editor.tree.grab_focus()
	var delete_key := InputEventKey.new()
	delete_key.keycode = KEY_DELETE
	delete_key.pressed = true
	editor.tree.gui_input.emit(delete_key)
	check(not editor.document.content.instances.has(id),"Delete key removes the setup selection")
	editor.document.undo()
	check(editor.document.content.instances.has(id),"Tree deletion is undoable")
	editor.document.undo()
	check(not editor.document.content.instances.has(id),"Palette placement is undoable")
	editor.document.redo()
	var checked_links := false
	for character in editor.document.content.schedules:
		editor.navigate("instances",character)
		var schedule_button: Button
		var story_button: Button
		for child in editor.inspector.get_children():
			if child is Button and child.text == "Open character schedule": schedule_button = child
			if child is Button and child.text.begins_with("Storylet: "): story_button = child
		if schedule_button == null or story_button == null: continue
		var story_id: String = story_button.text.trim_prefix("Storylet: ")
		schedule_button.grab_focus()
		schedule_button.pressed.emit()
		check(editor.inspector.get_child(0).text == "Schedules / " + character,"Focused schedule link opens its definition")
		editor.navigate("instances",character)
		for child in editor.inspector.get_children():
			if child is Button and child.text == "Storylet: " + story_id:
				child.grab_focus()
				child.pressed.emit()
				break
		check(editor.inspector.get_child(0).text == "Storylets / " + story_id,"Focused storylet link opens its definition")
		checked_links = true
		break
	check(checked_links,"Existing characters expose schedule and storylet links")
	editor.placement_template = "prop"
	editor.tool = "Place"
	var cancel := InputEventMouseButton.new()
	cancel.button_index = MOUSE_BUTTON_RIGHT
	cancel.pressed = true
	editor.canvas._gui_input(cancel)
	check(editor.tool == "Select" and editor.placement_template.is_empty(),"Right click cancels palette placement")
	editor.new_room()
	check(editor.document.content.rooms.has(editor.room_id),"New room is in setup tree")
	editor.document.undo()
	editor.room_id = "docks"
	editor.selected_kind = "storylets"
	editor.selected_id = "chandelier_warning"
	editor._refresh()
	editor.step(false)
	check(paused and editor.history_mode and game.sim.history.size() == 2,"Step advances and stays paused in History")
	editor.viewed_frame = 0
	editor._refresh()
	var snapshot: Dictionary = game.sim.s.duplicate(true)
	check(editor.inspected_state().frame == 0 and game.sim.s == snapshot,"Historical inspection leaves live state untouched")
	editor.history_mode = false
	editor.tabs.current_tab = 0
	editor._refresh()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/mission1-authoring-editor.png")
	editor.resume()
	check(not paused and not editor.overlay.visible,"Resume exits authoring")
	game.toggle_pause_editor()
	var next: Dictionary = editor.document.content.duplicate(true)
	next.rooms.studio = {"title":"Studio","scene":"","background_asset":"","size":[1175,700],"blocked":{}}
	next.instances.amelia.room = "studio"
	next.instances.amelia.position = [600,490]
	editor.document.replace_content(next,"Change start")
	var history_count: int = game.sim.history.size()
	editor.restart()
	check(game.sim.history.size() == history_count and game.rewind_index >= 0,"Authoring restart retains history until rewind finishes")
	game._finish_reset()
	check(game.sim.s.room == "studio" and game.shown_room == "studio" and game.sim.s.pos == [600,490] and game.sim.history.size() == 1,"Restart applies and renders a new room after rewind")
	var packed := preload("res://foundation/github_project.gd").package(editor.document)
	check(packed.ok,"Mission 1 authoring packages through the shared project serializer")
	if packed.ok: check(preload("res://foundation/github_project.gd").open_files(packed.files).ok,"Mission 1 project reopens through the shared project serializer")
	game.free()
	print(JSON.stringify({"suite":"mission1_authoring_ui","passed":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
