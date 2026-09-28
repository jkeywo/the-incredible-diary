extends Control

const Simulation = preload("res://foundation/simulation.gd")
const Journal = preload("res://foundation/journal.gd")
const Benchmark = preload("res://foundation/benchmark.gd")
var simulation: FoundationSimulation
var journal: FoundationJournal
var save_enabled := true
var paused := false
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
var viewed_tick := -1
var scrubber: HSlider
var source_editor: CodeEdit
var rewinding := false
var rewind_tick := 0

func _ready() -> void:
	simulation = Simulation.new()
	journal = Journal.new("user://foundation_run.jsonl")
	if FileAccess.file_exists(journal.path) or FileAccess.file_exists(journal.path + ".bak") or FileAccess.file_exists(journal.path + ".next"):
		var loaded := Journal.load(journal.path)
		if loaded.ok:
			simulation.restore_record(loaded)
			journal.saved_count = simulation.history.size() if str(loaded.reason).is_empty() and loaded.source == journal.path else 0
			journal.last_content_version = simulation.content.version
		else:
			save_enabled = false
	_build_ui()
	if not save_enabled:
		status_label.text = "Save unavailable: existing save invalid. It was not overwritten."
	else:
		_save()
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

func _process(delta: float) -> void:
	if rewinding:
		rewind_tick = maxi(0, rewind_tick - maxi(1, int(600.0 * delta)))
		viewed_tick = rewind_tick
		_refresh()
		if rewind_tick == 0:
			_finish_rewind()
		return
	if paused:
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
		if paused: _resume(false)
		else: _pause()
		_refresh()
	if paused and event.is_action_pressed("step_tick"):
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
	source_editor = CodeEdit.new()
	source_editor.text = simulation.content.dialogue
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
	if paused: _resume(false)
	else: _pause()
	_refresh()

func _step_tick() -> void:
	if paused and _apply_pending(-1):
		simulation.tick()
		_save()
		viewed_tick = -1
	_refresh()

func _next_event() -> void:
	if paused and _apply_pending(-1):
		simulation.step_next_event()
		_save()
		viewed_tick = -1
	_refresh()

func _other_room() -> void:
	inspected_room = "corridor" if inspected_room == "service" else "service"
	_refresh()

func _on_scrub(value: float) -> void:
	viewed_tick = int(value)
	_refresh()

func _return_live() -> void:
	viewed_tick = -1
	_refresh()

func _resume_from_here() -> void:
	_resume(true)
	_refresh()

func _draw_world() -> void:
	var shown := _shown_state()
	canvas.draw_rect(Rect2(20, 20, 880, 310), Color("293c48") if inspected_room == "service" else Color("38434a"))
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(35, 50), inspected_room.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	for actor_id in shown.actors:
		var actor: Dictionary = shown.actors[actor_id]
		if actor.room != inspected_room:
			continue
		var point := Vector2(20 + float(actor.x) * 2.0, 20 + float(actor.y))
		canvas.draw_circle(point, 14, Color("e9b96e") if actor_id == "amelia" else Color("6bc7bb"))
		canvas.draw_string(font, point + Vector2(-25, -19), actor_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	for interaction in simulation.content.interactions:
		if interaction.room == inspected_room:
			var point := Vector2(20 + float(interaction.x) * 2.0, 20 + float(interaction.y))
			canvas.draw_rect(Rect2(point - Vector2(8, 8), Vector2(16, 16)), Color("cf7985"))
			canvas.draw_string(font, point + Vector2(-20, 32), interaction.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	if viewed_tick < 0 and inspected_room == simulation.state.actors.amelia.room:
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

func _refresh() -> void:
	if not is_instance_valid(state_label):
		return
	var shown := _shown_state()
	var actor: Dictionary = shown.actors.chatterbox
	state_label.text = "Tick %d / %d  |  Hour %d  |  %s  |  Chatterbox: %s → %s  |  Viewing: %s  |  Valve: %s" % [shown.tick, simulation.state.tick, mini(6, 1 + int(shown.tick / Simulation.TICKS_PER_HOUR)), "PAUSED" if paused else "RUNNING", actor.room, actor.destination, inspected_room, "closed" if shown.flags.get("close_valve", false) else "open"]
	if is_instance_valid(scrubber):
		scrubber.max_value = simulation.state.tick
		if viewed_tick < 0:
			scrubber.set_value_no_signal(simulation.state.tick)
	canvas.queue_redraw()

func _shown_state() -> Dictionary:
	return simulation.inspect_at(viewed_tick) if viewed_tick >= 0 else simulation.inspect()

func _local_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if simulation.dialogue_available():
		choices.append({"kind": "dialogue", "id": "chatterbox", "label": "Talk"})
	for interaction in simulation.available_interactions():
		choices.append({"kind": "action", "id": interaction.id, "label": interaction.label})
	return choices

func _pause() -> void:
	paused = true
	source_editor.visible = true
	status_label.text = "Paused. Edit the Dialogue Manager scene, then resume to validate and apply."

func _resume(from_history: bool) -> void:
	if not paused:
		return
	var target_tick := viewed_tick if from_history and viewed_tick >= 0 else -1
	if not _apply_pending(target_tick):
		return
	_save()
	paused = false
	viewed_tick = -1
	source_editor.visible = false
	status_label.text = "Continued from recorded time" if target_tick >= 0 else "Running"

func _apply_pending(target_tick: int) -> bool:
	var next_content := simulation.content.duplicate(true)
	if source_editor.text != simulation.content.dialogue:
		next_content.dialogue = source_editor.text
		next_content.version = "edit-%s" % source_editor.text.md5_text().substr(0, 10)
	var result := simulation.continue_with_content(next_content, target_tick)
	if not result.ok:
		status_label.text = "Resume blocked: " + str(result.reason)
		return false
	return true

func _save() -> void:
	if not save_enabled: return
	var result := journal.save(simulation)
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
	paused = true
	rewind_tick = simulation.state.tick
	viewed_tick = rewind_tick
	source_editor.visible = false
	status_label.text = "Rewinding recorded history. Press R again to skip."
	if rewind_tick == 0: _finish_rewind()

func _finish_rewind() -> void:
	rewinding = false
	simulation.reset_loop()
	viewed_tick = -1
	inspected_room = simulation.state.actors.amelia.room
	paused = false
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
	var loaded := Journal.load("user://foundation_benchmark.jsonl")
	var passed: bool = loaded.ok and loaded.history.size() == Simulation.LEG_TICKS + 1 and loaded.history[-1].tick == Simulation.LEG_TICKS
	var report := {"passed": passed, "states": loaded.history.size() if loaded.ok else 0, "reason": loaded.reason, "platform": OS.get_name()}
	var encoded := JSON.stringify(report)
	print("FOUNDATION_BENCHMARK_REOPEN ", encoded)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.body.dataset.foundationVerification = " + JSON.stringify(encoded) + ";")
		status_label.text = "Full-leg browser reopen: " + ("PASS" if passed else "FAIL")
