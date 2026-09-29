extends SceneTree

const Opening = preload("res://mission1/opening.tscn")
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
	var game := Opening.instantiate()
	game.configure({}, false)
	title.set_game_world(game)
	title._game_world = game
	game.enable_controls()
	for direction in ["right", "left", "up", "down"]:
		Input.action_press("move_" + direction)
		var frames := {}
		for i in range(40):
			await physics_frame
			frames[game.amelia.frame] = true
		check(frames.size() == 4 and game.amelia.animation == "walk_" + direction, "full looping walk: " + direction)
		Input.action_release("move_" + direction)
	press_pause()
	check(paused and editor.overlay.visible, "docks inherits shared editor through title host")
	var position: Vector2 = game.player_position
	var time: int = game.elapsed_ms
	var frame: int = game.amelia.frame
	var phase: float = game.amelia.frame_progress
	var recorded: Array = game.history.duplicate(true)
	Input.action_press("move_right")
	await create_timer(0.25, true).timeout
	check(game.player_position == position and game.elapsed_ms == time, "pause freezes movement and game clock")
	check(game.amelia.frame == frame and game.amelia.frame_progress == phase, "pause freezes animation phase")
	check(game.history == recorded, "pause does not fabricate history")
	press_pause()
	await create_timer(0.15).timeout
	Input.action_release("move_right")
	check(not paused and game.player_position != position and game.elapsed_ms > time, "resume continues same world")
	var saved := {"room": game.room_id, "position": [game.player_position.x, game.player_position.y], "facing": game.facing, "elapsed_ms": game.elapsed_ms, "history": game.history.duplicate(true)}
	var continued := Opening.instantiate()
	continued.configure(saved, false)
	title.set_game_world(continued)
	title._game_world = continued
	continued.enable_controls()
	press_pause()
	check(paused and editor.overlay.visible and continued.player_position == Vector2(saved.position[0], saved.position[1]), "continued opening uses same default editor at loaded position")
	press_pause()
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
	quit(0 if failures.is_empty() else 1)

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
