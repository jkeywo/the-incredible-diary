extends Control

const Simulation = preload("res://foundation/run.gd")
const AuthoringSession = preload("res://foundation/authoring_session.gd")
const Benchmark = preload("res://foundation/benchmark.gd")
const AuthoringDocument = preload("res://foundation/authoring_document.gd")
const CharacterSprite = preload("res://assets/characters/character_sprite.gd")
const ValveSheet = preload("res://assets/props/valve_states.png")
const ACTOR_ART := {"amelia": "player", "chatterbox": "matron", "guest": "rake"}
const ACTOR_LABELS := {"amelia": "Amelia", "chatterbox": "Chatter Box", "guest": "Guest"}
var simulation: FoundationRun
var session: FoundationAuthoringSession
var document: FoundationAuthoringDocument
var save_enabled := true
var accumulator := 0.0
var inspected_room := "service"
var status_label: Label
var state_label: Label
var canvas: Control
var queued_interaction := ""
var queued_cancel := false
var queued_dialogue_start := false
var queued_dialogue_advance := false
var wheel_selection := 0
var scrubber: HSlider
var source_editor: CodeEdit
var rewinding := false
var rewind_tick := 0
var actor_frames: Dictionary = {}
var facing_history: Dictionary = {}

func _ready() -> void:
	simulation = Simulation.new()
	for actor_id in ACTOR_ART:
		actor_frames[actor_id] = CharacterSprite.make_frames(ACTOR_ART[actor_id])
	simulation.attach_journal("user://foundation_run_v2.jsonl")
	var save_path: String = simulation.journal.path
	var has_new_save := FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak") or FileAccess.file_exists(save_path + ".next")
	var prior_foundation_save := FileAccess.file_exists("user://foundation_run.jsonl")
	if has_new_save:
		var loaded := simulation.load_saved()
		if not loaded.ok:
			save_enabled = false
	session = AuthoringSession.new(simulation)
	document = session.document
	_build_ui()
	if not save_enabled:
		status_label.text = "Save unavailable: existing save invalid. It was not overwritten."
	else:
		_save()
		if prior_foundation_save and not has_new_save:
			status_label.text = "Fresh foundation run. The previous save file remains untouched."
	_refresh()
	var benchmark_requested := "--foundation-benchmark" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		benchmark_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('foundation_benchmark')"))
	if benchmark_requested:
		call_deferred("_run_benchmark")
	var verify_requested := "--foundation-verify-benchmark" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		verify_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('foundation_verify_benchmark')"))
	if verify_requested:
		call_deferred("_verify_benchmark")
	var editor_smoke_requested := "--editor-smoke" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		editor_smoke_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('editor_smoke')"))
	if editor_smoke_requested:
		call_deferred("_run_editor_smoke")

func _process(delta: float) -> void:
	if rewinding:
		rewind_tick = maxi(0, rewind_tick - maxi(1, int(600.0 * delta)))
		session.view_tick(rewind_tick)
		_refresh()
		if rewind_tick == 0:
			_finish_rewind()
		return
	if session.paused:
		return
	accumulator += minf(delta, 0.25)
	while accumulator >= 0.1:
		accumulator -= 0.1
		var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var command := {"x": movement.x, "y": movement.y}
		var right_axis := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if right_axis.length() > 0.6:
			var choices := _local_choices()
			if not choices.is_empty():
				wheel_selection = posmod(int(round((right_axis.angle() + PI / 2.0) / TAU * choices.size())), choices.size())
		if not queued_interaction.is_empty():
			command.start_interaction = queued_interaction
			queued_interaction = ""
		if queued_cancel:
			command.cancel_action = true
			queued_cancel = false
		if queued_dialogue_start:
			command.start_dialogue = true
			queued_dialogue_start = false
		if queued_dialogue_advance:
			command.advance_dialogue = true
			queued_dialogue_advance = false
		simulation.tick(command)
		_save()
		inspected_room = simulation.state.actors.amelia.room
		if not simulation.events.is_empty():
			status_label.text = str(simulation.events[-1].detail)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_loop"):
		_reset_pressed()
		return
	if rewinding: return
	if event.is_action_pressed("pause_game"):
		if session.paused: _resume(false)
		else: _pause()
		_refresh()
	if session.paused and event.is_action_pressed("step_tick"):
		_step_tick()
	if event.is_action_pressed("interaction_one") or event.is_action_pressed("interaction_two") or event.is_action_pressed("wheel_confirm"):
		if not simulation.state.dialogue.is_empty():
			queued_dialogue_advance = true
		else:
			var choices := _local_choices()
			var selection := 0 if event.is_action_pressed("interaction_one") else 1 if event.is_action_pressed("interaction_two") else wheel_selection
			if selection < choices.size():
				if choices[selection].kind == "dialogue": queued_dialogue_start = true
				else: queued_interaction = choices[selection].id
			else:
				status_label.text = "No local interaction is available."
	if event.is_action_pressed("cancel_action"):
		queued_cancel = true

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("15232d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var title := Label.new()
	title.text = "AMELIA / TWO-ROOM FOUNDATION"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	state_label = Label.new()
	column.add_child(state_label)
	canvas = Control.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.custom_minimum_size = Vector2(900, 350)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.draw.connect(_draw_world)
	column.add_child(canvas)
	var controls := HFlowContainer.new()
	column.add_child(controls)
	_button(controls, "Pause / resume (Space)", _toggle_pause)
	_button(controls, "Single tick (.)", _step_tick)
	_button(controls, "Next event", _next_event)
	_button(controls, "Inspect other room", _other_room)
	scrubber = HSlider.new()
	scrubber.min_value = 0
	scrubber.step = 1
	scrubber.value_changed.connect(_on_scrub)
	column.add_child(scrubber)
	_button(controls, "Return to live", _return_live)
	_button(controls, "Resume from here", _resume_from_here)
	_button(controls, "Retry save", _retry_save)
	_button(controls, "Rewind / skip (R)", _reset_pressed)
	_button(controls, "Undo edit", _undo_edit)
	_button(controls, "Redo edit", _redo_edit)
	source_editor = CodeEdit.new()
	source_editor.text = document.source_draft
	source_editor.text_changed.connect(func(): session.set_draft(source_editor.text))
	source_editor.custom_minimum_size.y = 110
	source_editor.visible = false
	column.add_child(source_editor)
	status_label = Label.new()
	status_label.text = "WASD / left stick moves Amelia. 1–2 / right stick + RB chooses a local action."
	column.add_child(status_label)

func _button(parent: Node, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)

func _toggle_pause() -> void:
	if session.paused: _resume(false)
	else: _pause()
	_refresh()

func _step_tick() -> void:
	if session.paused:
		var result := session.step_tick()
		if not result.ok:
			status_label.text = "Step blocked: " + str(result.reason)
			return
		_save()
	_refresh()

func _next_event() -> void:
	if session.paused:
		var result := session.step_next_event()
		if not result.ok:
			status_label.text = "Step blocked: " + str(result.reason)
			return
		_save()
	_refresh()

func _other_room() -> void:
	inspected_room = "corridor" if inspected_room == "service" else "service"
	_refresh()

func _on_scrub(value: float) -> void:
	session.view_tick(int(value))
	_refresh()

func _return_live() -> void:
	session.return_live()
	_refresh()

func _resume_from_here() -> void:
	_resume(true)
	_refresh()

func _draw_world() -> void:
	var shown := _shown_state()
	var before := simulation.inspect_at(int(shown.tick) - 1) if shown.tick > 0 else {}
	canvas.draw_rect(Rect2(20, 20, 880, 310), Color("293c48") if inspected_room == "service" else Color("38434a"))
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(35, 50), inspected_room.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	for actor_id in shown.actors:
		var actor: Dictionary = shown.actors[actor_id]
		if actor.room != inspected_room:
			continue
		var point := Vector2(20 + float(actor.x) * 2.0, 20 + float(actor.y))
		_draw_actor(actor_id, shown, before, point)
		canvas.draw_string(font, point + Vector2(-28, -54), ACTOR_LABELS.get(actor_id, actor_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	for interaction in simulation.content.interactions:
		if interaction.room == inspected_room:
			var point := Vector2(20 + float(interaction.x) * 2.0, 20 + float(interaction.y))
			if interaction.id == "valve":
				var source_x := 32 if shown.flags.get("close_valve", false) else 0
				canvas.draw_texture_rect_region(ValveSheet, Rect2(point - Vector2(16, 48), Vector2(32, 48)), Rect2(source_x, 0, 32, 48))
			else:
				canvas.draw_rect(Rect2(point - Vector2(8, 8), Vector2(16, 16)), Color("cf7985"))
			canvas.draw_string(font, point + Vector2(-20, 32), interaction.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	if session.viewed_tick < 0 and inspected_room == simulation.state.actors.amelia.room:
		var amelia: Dictionary = simulation.state.actors.amelia
		var center := Vector2(20 + float(amelia.x) * 2.0, 20 + float(amelia.y))
		var choices := _local_choices()
		for i in choices.size():
			var angle := -PI / 2.0 + TAU * float(i) / float(choices.size())
			var wheel_point := center + Vector2.from_angle(angle) * 70.0
			canvas.draw_circle(wheel_point, 26, Color("526d81") if i == wheel_selection else Color("344f62"))
			canvas.draw_string(font, wheel_point + Vector2(-20, 5), "%d %s" % [i + 1, choices[i].label], HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	if not shown.dialogue.is_empty():
		canvas.draw_string(font, Vector2(40, 270), shown.dialogue.line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	if not shown.action.is_empty():
		var action: Dictionary = shown.action
		canvas.draw_rect(Rect2(250, 290, 400, 15), Color("101d25"))
		canvas.draw_rect(Rect2(250, 290, 400.0 * float(action.progress) / float(action.duration), 15), Color("d4aa68"))


func _draw_actor(actor_id: String, shown: Dictionary, before: Dictionary, point: Vector2) -> void:
	if not actor_frames.has(actor_id):
		return
	var frames: SpriteFrames = actor_frames[actor_id]
	var direction := _recorded_facing(actor_id, int(shown.tick))
	var action := "idle"
	if before.has("actors"):
		if before.actors.has(actor_id):
			var prior: Dictionary = before.actors[actor_id]
			var current: Dictionary = shown.actors[actor_id]
			if prior.room == current.room:
				var motion := Vector2(float(current.x) - float(prior.x), float(current.y) - float(prior.y))
				if not motion.is_zero_approx():
					action = "walk"
	if actor_id == "amelia" and not shown.action.is_empty():
		action = "bob"
	elif not shown.dialogue.is_empty():
		var speaker := str(shown.dialogue.get("line", "")).get_slice(":", 0).strip_edges().to_lower()
		if speaker == actor_id:
			action = "talk"
	var animation := "%s_%s" % [action, direction]
	var count := frames.get_frame_count(animation)
	var speed := frames.get_animation_speed(animation)
	var frame := int(float(shown.tick) * speed / 10.0) % count
	canvas.draw_texture_rect(frames.get_frame_texture(animation, frame), Rect2(point - Vector2(16, 48), Vector2(32, 48)), false)


func _recorded_facing(actor_id: String, tick: int) -> String:
	var cached: Array = facing_history.get(actor_id, [])
	if cached.size() > simulation.history.size():
		cached.clear()
	while cached.size() <= tick and cached.size() < simulation.history.size():
		var index := cached.size()
		var direction := "down" if index == 0 else str(cached[index - 1])
		if index > 0:
			var prior: Dictionary = simulation.history[index - 1].actors[actor_id]
			var current: Dictionary = simulation.history[index].actors[actor_id]
			if prior.room == current.room:
				var motion := Vector2(float(current.x) - float(prior.x), float(current.y) - float(prior.y))
				if not motion.is_zero_approx():
					if absf(motion.x) >= absf(motion.y):
						direction = "right" if motion.x > 0.0 else "left"
					else:
						direction = "down" if motion.y > 0.0 else "up"
		cached.append(direction)
	facing_history[actor_id] = cached
	return str(cached[tick]) if tick < cached.size() else "down"

func _refresh() -> void:
	if not is_instance_valid(state_label):
		return
	var shown := _shown_state()
	var actor: Dictionary = shown.actors.chatterbox
	state_label.text = "Tick %d / %d  |  Hour %d  |  %s  |  Chatterbox: %s → %s  |  Viewing: %s  |  Valve: %s" % [shown.tick, simulation.state.tick, mini(6, 1 + int(shown.tick / Simulation.TICKS_PER_HOUR)), "PAUSED" if session.paused else "RUNNING", actor.room, actor.destination, inspected_room, "closed" if shown.flags.get("close_valve", false) else "open"]
	if is_instance_valid(scrubber):
		scrubber.max_value = simulation.state.tick
		if session.viewed_tick < 0:
			scrubber.set_value_no_signal(simulation.state.tick)
	canvas.queue_redraw()

func _shown_state() -> Dictionary:
	return session.inspect()

func _local_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if simulation.dialogue_available():
		choices.append({"kind": "dialogue", "id": "chatterbox", "label": "Talk"})
	for interaction in simulation.available_interactions():
		choices.append({"kind": "action", "id": interaction.id, "label": interaction.label})
	return choices

func _pause() -> void:
	session.pause()
	source_editor.text = document.source_draft
	source_editor.visible = true
	status_label.text = "Paused. Edit the Dialogue Manager scene, then resume to validate and apply."

func _resume(from_history: bool) -> void:
	if not session.paused:
		return
	var target_tick := session.viewed_tick if from_history and session.viewed_tick >= 0 else -1
	var result := session.resume(from_history)
	if not result.ok:
		status_label.text = "Resume blocked: " + str(result.reason)
		return
	_save()
	source_editor.visible = false
	status_label.text = "Continued from recorded time" if target_tick >= 0 else "Running"
	if target_tick >= 0:
		facing_history.clear()

func _undo_edit() -> void:
	if not session.paused or rewinding:
		return
	document.set_source(source_editor.text)
	var label := document.undo()
	if label.is_empty():
		status_label.text = "No authoring edit to undo."
		return
	source_editor.text = document.source_draft
	status_label.text = "Undid: " + label

func _redo_edit() -> void:
	if not session.paused or rewinding:
		return
	document.set_source(source_editor.text)
	var label := document.redo()
	if label.is_empty():
		status_label.text = "No authoring edit to redo."
		return
	source_editor.text = document.source_draft
	status_label.text = "Redid: " + label

func _save() -> void:
	if not save_enabled: return
	var result := simulation.persist()
	if not result.ok:
		save_enabled = false
		if is_instance_valid(status_label):
			status_label.text = "Save failed: " + str(result.reason)

func _retry_save() -> void:
	save_enabled = true
	_save()

func _reset_pressed() -> void:
	if rewinding:
		_finish_rewind()
		return
	rewinding = true
	session.begin_rewind()
	rewind_tick = simulation.state.tick
	source_editor.visible = false
	status_label.text = "Rewinding recorded history. Press R again to skip."
	if rewind_tick == 0: _finish_rewind()

func _finish_rewind() -> void:
	rewinding = false
	session.finish_rewind()
	facing_history.clear()
	inspected_room = simulation.state.actors.amelia.room
	_save()
	status_label.text = "New loop. Diary observations retained; world and current-loop knowledge reset."
	_refresh()

func _run_benchmark() -> void:
	var save_path := "user://foundation_benchmark.jsonl"
	var report_path := "user://foundation_benchmark_result.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--benchmark-save-path="):
			save_path = argument.trim_prefix("--benchmark-save-path=")
		if argument.begins_with("--benchmark-report="):
			report_path = argument.trim_prefix("--benchmark-report=")
	var report: Dictionary = Benchmark.run(save_path)
	var encoded := JSON.stringify(report)
	print("FOUNDATION_BENCHMARK ", encoded)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.foundationBenchmark = " + encoded + "; document.body.dataset.foundationBenchmark = " + JSON.stringify(encoded) + ";")
		status_label.text = "Full-leg benchmark: " + ("PASS" if report.passed else "FAIL")
	else:
		var output := FileAccess.open(report_path, FileAccess.WRITE)
		if output != null:
			output.store_string(encoded)
			output.close()
		get_tree().quit(0 if report.passed else 1)

func _verify_benchmark() -> void:
	var reopened := Simulation.new()
	reopened.attach_journal("user://foundation_benchmark.jsonl")
	var loaded := reopened.load_saved()
	var passed: bool = loaded.ok and loaded.history.size() == Simulation.LEG_TICKS + 1 and loaded.history[-1].tick == Simulation.LEG_TICKS
	var report := {"passed": passed, "states": loaded.history.size() if loaded.ok else 0, "reason": loaded.reason, "platform": OS.get_name()}
	var encoded := JSON.stringify(report)
	print("FOUNDATION_BENCHMARK_REOPEN ", encoded)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.body.dataset.foundationVerification = " + JSON.stringify(encoded) + ";")
		status_label.text = "Full-leg browser reopen: " + ("PASS" if passed else "FAIL")

func _run_editor_smoke() -> void:
	save_enabled = false
	simulation = Simulation.new()
	session = AuthoringSession.new(simulation)
	document = session.document
	source_editor.text = document.source_draft
	_pause()
	var revised := document.source_draft.replace("delay_guest(40)", "delay_guest(80)")
	source_editor.text = revised
	_undo_edit()
	var undone := source_editor.text != revised
	_redo_edit()
	var redone := source_editor.text == revised
	_resume(false)
	var applied: bool = not session.paused and simulation.content.dialogue == revised
	for i in range(10): simulation.tick({"x": 1.0})
	simulation.tick({"start_dialogue": true})
	simulation.tick({"advance_dialogue": true})
	for i in range(Simulation.DIALOGUE_TICKS): simulation.tick()
	var report := {"passed": undone and redone and applied and simulation.state.flags.get("guest_delay_ticks", 0) == 80, "undo": undone, "redo": redone, "applied": applied, "future_effect": simulation.state.flags.get("guest_delay_ticks", 0), "platform": OS.get_name()}
	var encoded := JSON.stringify(report)
	print("EDITOR_SMOKE ", encoded)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.body.dataset.editorSmoke = " + JSON.stringify(encoded) + ";")
	else:
		get_tree().quit(0 if report.passed else 1)
