extends SceneTree

const Play = preload("res://mission1/play.tscn")
const Sim = preload("res://mission1/simulation.gd")
const Save = preload("res://mission1/save.gd")
const SAVE_PATH := "res://build/pause-editor-test.journal"
const Title = preload("res://assets/ui/mission_1/title_screen.tscn")
var failures: Array[String] = []

class PlainGameplay:
	extends Node
	@export_range(1, 100) var speed := 10

class AuthoredGameplay:
	extends Node
	var toggled := false
	func toggle_pause_editor() -> void:
		toggled = not toggled


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)


func press_pause() -> void:
	var event := InputEventAction.new()
	event.action = "pause_game"
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _run() -> void:
	var editor := root.get_node("PauseEditor")
	var plain := PlainGameplay.new()
	root.add_child(plain)
	current_scene = plain
	await process_frame
	press_pause()
	check(paused and editor.overlay.visible, "unmodified scene gets default pause editor")
	await check_panels(editor)
	editor._edit(plain, "speed", 20)
	check(plain.speed == 20, "inspector edits exported property")
	editor._undo()
	check(plain.speed == 10, "undo restores property")
	editor._redo()
	check(plain.speed == 20, "redo restores edit")
	press_pause()
	check(not paused and not editor.overlay.visible, "Space resumes and hides editor")
	editor._edit(plain, "speed", 30)
	check(plain.speed == 20, "editing disabled while running")
	plain.free()
	var title := Title.instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	press_pause()
	check(not paused, "title menu does not enter editor")
	var game := Play.instantiate()
	game.sim = Sim.new(false)
	game.configure({}, false)
	title.set_game_world(game)
	title._game_world = game
	game.enable_controls()
	for direction in ["right", "left", "up", "down"]:
		Input.action_press("move_" + direction)
		var frames := {}
		for i in range(40):
			await physics_frame
			frames[game.actors.amelia.frame] = true
		check(frames.size() == 4 and game.actors.amelia.animation == "walk_" + direction, "full looping walk: " + direction)
		Input.action_release("move_" + direction)
	press_pause()
	check(paused and game.authoring_editor.overlay.visible, "docks opens authored editor through title host")
	var position: Array = game.sim.s.pos.duplicate()
	var time: int = game.sim.s.tick
	var recorded_frame: int = game.sim.s.frame
	var frame: int = game.actors.amelia.frame
	var phase: float = game.actors.amelia.frame_progress
	var recorded: Array = game.sim.history.duplicate(true)
	Input.action_press("move_right")
	await create_timer(0.25, true).timeout
	check(game.sim.s.pos == position and game.sim.s.tick == time and game.sim.s.frame == recorded_frame, "pause freezes movement and game clock")
	check(game.actors.amelia.frame == frame and game.actors.amelia.frame_progress == phase, "pause freezes animation phase")
	check(game.sim.history == recorded, "pause does not fabricate history")
	press_pause()
	await create_timer(0.15).timeout
	Input.action_release("move_right")
	check(not paused and game.sim.s.pos != position and game.sim.s.tick > time, "resume continues same world")
	Save.clear(SAVE_PATH)
	check(Save.new().save_run(game.sim, SAVE_PATH).ok, "current voyage saved to isolated fixture")
	var loaded := Save.load_saved(SAVE_PATH)
	check(loaded.ok, "current voyage fixture loads")
	var saved: Dictionary = loaded.data
	var continued := Play.instantiate()
	continued.configure(saved, false)
	title.set_game_world(continued)
	title._game_world = continued
	continued.enable_controls()
	press_pause()
	check(paused and continued.authoring_editor.overlay.visible and continued.sim.s == saved.current and continued.sim.history == saved.history, "continued mission uses shared editor with recorded state")
	press_pause()
	Save.clear(SAVE_PATH)
	var tutorial := Play.instantiate()
	tutorial.configure({}, false)
	title.set_game_world(tutorial)
	title._game_world = tutorial
	tutorial.enable_controls()
	await create_timer(0.2).timeout
	check(tutorial.sim.s.tick == 0 and tutorial.sim.s.frame > 0, "tutorial records frames while voyage clock is frozen")
	press_pause()
	var tutorial_state: Dictionary = tutorial.sim.s.duplicate(true)
	var tutorial_history: Array = tutorial.sim.history.duplicate(true)
	await create_timer(0.2, true).timeout
	check(tutorial.sim.s == tutorial_state and tutorial.sim.history == tutorial_history, "pause freezes tutorial recorded frames")
	press_pause()
	await create_timer(0.2).timeout
	check(tutorial.sim.s.tick == 0 and tutorial.sim.s.frame > tutorial_state.frame, "tutorial frames resume without advancing voyage time")
	title.free()
	var authored := AuthoredGameplay.new()
	root.add_child(authored)
	current_scene = authored
	press_pause()
	check(authored.toggled and not paused and not editor.overlay.visible, "authoring adapter owns its simulation and editor")
	press_pause()
	check(not authored.toggled, "authoring adapter resumes through shared shortcut")
	authored.free()
	await process_frame
	print(JSON.stringify({"suite": "pause_editor", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://tests/shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func check_panels(editor: Node) -> void:
	var panel = editor.panels["Scene"]
	var button_count: int = editor.dock.get_child_count()
	panel.attach_dock(editor.dock)
	panel.minimise_panel()
	panel.minimise_panel()
	check(not panel.visible and panel.restore_button.visible and editor.dock.get_child_count() == button_count, "minimise and attachment are idempotent")
	panel.restore_button.pressed.emit()
	check(panel.visible and not panel.restore_button.visible, "dock button restores panel")
	panel.minimise_panel()
	editor._show_panel("Scene")
	check(panel.visible and not panel.restore_button.visible, "menu reopening removes dock button")
	panel.minimise_panel()
	panel.close_panel()
	check(not panel.visible and not panel.restore_button.visible, "closing minimised panel hides both")
	editor.resume()
	editor.pause(editor.edited_scene)
	check(panel.visible and not panel.restore_button.visible, "generic editor reopens panels on pause")
	var harness = preload("res://foundation/harness.gd").new()
	var host := Control.new()
	host.size = Vector2(600, 500)
	root.add_child(host)
	var dock := HBoxContainer.new()
	root.add_child(dock)
	harness.panel_layer = host
	harness.editor_overlay = host
	harness.panel_dock = dock
	harness.session = preload("res://foundation/authoring_session.gd").new(preload("res://foundation/run.gd").new())
	harness.session.pause()
	var authored = harness._make_panel("Fixture", Vector2(40, 60), Vector2(400, 300))
	harness._open_panel("Fixture")
	authored.minimise_panel()
	host.hide()
	host.show()
	check(not authored.visible and authored.restore_button.visible, "foundation overlay preserves minimised state")
	host.size = Vector2(320, 250)
	harness._open_panel("Fixture")
	check(authored.visible and not authored.restore_button.visible and authored.size.x <= 304, "foundation reopen fits resized host")
	authored.close_panel()
	harness.session.paused = false
	harness._open_panel("Fixture")
	check(not authored.visible, "foundation panel opening remains pause gated")
	var restore = authored.restore_button
	authored.free()
	await process_frame
	check(not is_instance_valid(restore) and dock.get_child_count() == 0, "panel cleanup removes dock button")
	harness.free()
	host.free()
	dock.free()
