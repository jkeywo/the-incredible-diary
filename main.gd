extends Control

# A deliberately small feasibility probe, not Mission 1 or its full scheduler.
const DEFAULT_SOURCE = "~ start\nChatterbox: Thank you for stopping the steam.\ndo delay_guest(1)\nGuest: I will stay and listen.\n=> END"
var hour: int = 4
var steam_on: bool = true
var rescued: bool = false
var guest_arrival: int = 4
var chatter_position: float = 0.0
var guest_position: float = 0.0
var known_procedure: bool = true
var applied_source: String = DEFAULT_SOURCE
var dialogue: DialogueResource
var cue: String = "start"
var log_lines: Array[String] = []
var busy: bool = false
var editor: CodeEdit
var status: Label
var state_label: Label
var log_view: RichTextLabel
var world: Control
var test_results: Array[Dictionary] = []
var test_mode: bool = false
var save_path: String = "user://probe_save.json"

func _ready() -> void:
	test_mode = "--probe-test" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		test_mode = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('probe_test')"))
	_build_ui()
	apply_source(DEFAULT_SOURCE)
	if test_mode:
		save_path = "user://probe_test.json"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--save-path="): save_path = arg.trim_prefix("--save-path=")
		call_deferred("_run_tests")
	elif FileAccess.file_exists(save_path):
		load_snapshot()
	_refresh()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("17212b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var title := Label.new()
	title.text = "AMELIA  /  LIVE AUTHORING PROBE"
	title.add_theme_font_size_override("font_size", 25)
	root.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Edit a scene, apply it, then step the interaction. Native + web feasibility test."
	root.add_child(subtitle)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 555
	root.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 500
	split.add_child(left)
	var source_label := Label.new()
	source_label.text = "SCENE SCRIPT — Dialogue Manager 4.1"
	left.add_child(source_label)
	editor = CodeEdit.new()
	editor.text = DEFAULT_SOURCE
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.gutters_draw_line_numbers = true
	editor.add_theme_font_size_override("font_size", 17)
	left.add_child(editor)
	var apply := Button.new()
	apply.text = "Validate & apply edited script"
	apply.pressed.connect(func(): apply_source(editor.text))
	left.add_child(apply)
	var help := Label.new()
	help.text = "Try changing delay_guest(1) to delay_guest(2).\nApply resets the dialogue cursor; world changes are retained."
	left.add_child(help)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	state_label = Label.new()
	right.add_child(state_label)
	world = Control.new()
	world.custom_minimum_size = Vector2(470, 195)
	world.draw.connect(_draw_world)
	right.add_child(world)
	var controls := HFlowContainer.new()
	right.add_child(controls)
	_add_button(controls, "Stop steam", stop_steam)
	_add_button(controls, "Next scene line", func(): next_line())
	_add_button(controls, "Advance time", advance_time)
	_add_button(controls, "Save", save_snapshot)
	_add_button(controls, "Reload", load_snapshot)
	_add_button(controls, "Reset loop", reset_loop)
	log_view = RichTextLabel.new()
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.add_theme_font_size_override("normal_font_size", 17)
	right.add_child(log_view)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 44
	root.add_child(status)

func _add_button(parent: Node, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	parent.add_child(b)

func _draw_world() -> void:
	world.draw_rect(Rect2(0, 0, 225, 185), Color("293d4b"))
	world.draw_rect(Rect2(240, 0, 225, 185), Color("32444d"))
	var font := ThemeDB.fallback_font
	world.draw_string(font, Vector2(12, 25), "SERVICE ROOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	world.draw_string(font, Vector2(253, 25), "PARTY CORRIDOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	world.draw_circle(Vector2(60 + chatter_position * 190, 92), 15, Color("efb16b"))
	world.draw_circle(Vector2(360 + guest_position * 40, 115), 15, Color("6fc7c4"))
	world.draw_string(font, Vector2(16, 155), "Chatterbox", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	world.draw_string(font, Vector2(320, 155), "Guest", HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	if steam_on:
		world.draw_rect(Rect2(148, 45, 43, 90), Color(0.8, 0.88, 0.9, 0.55))

func _refresh() -> void:
	if not is_instance_valid(state_label): return
	state_label.text = "Hour %d  |  Steam: %s\nRescued: %s  |  Guest arrives: Hour %d" % [hour, "ON" if steam_on else "OFF", rescued, guest_arrival]
	log_view.text = "\n".join(log_lines)
	world.queue_redraw()

func apply_source(source: String) -> bool:
	if busy:
		status.text = "Wait for the current dialogue step before applying."
		return false
	var result := DMCompiler.compile_string(source, "")
	if not result.errors.is_empty():
		status.text = "Edit rejected; previous script retained. Line %d: %s" % [result.errors[0].line_number + 1, DMConstants.get_error_message(result.errors[0].error)]
		return false
	if not result.cues.has("start"):
		status.text = "Edit rejected: a ~ start cue is required."
		return false
	dialogue = DialogueManager.create_resource_from_text(source)
	applied_source = source
	cue = "start"
	editor.text = source
	status.text = "Applied in the running game. Dialogue restarts at start; world state is preserved."
	return true

func stop_steam() -> void:
	steam_on = false
	rescued = true
	chatter_position = 1.0
	log_lines.append("Steam off. Chatterbox escapes and meets Guest.")
	_refresh()

func delay_guest(amount: int) -> void:
	guest_arrival += amount
	log_lines.append("World command: delay Guest by %d Hour(s)." % amount)
	_refresh()

func next_line() -> String:
	if busy or not rescued or cue == "":
		return ""
	busy = true
	var line: DialogueLine = await dialogue.get_next_dialogue_line(cue, [self])
	if line == null:
		cue = ""
		busy = false
		return ""
	cue = line.next_id
	var text := line.character + ": " + line.text
	log_lines.append(text)
	busy = false
	_refresh()
	return text

func advance_time() -> void:
	hour += 1
	if hour >= guest_arrival: guest_position = 1.0
	_refresh()

func snapshot() -> Dictionary:
	return {"schema": 1, "source": applied_source, "cue": cue, "hour": hour, "steam_on": steam_on, "rescued": rescued, "guest_arrival": guest_arrival, "chatter_position": chatter_position, "guest_position": guest_position, "known_procedure": known_procedure, "log": log_lines}

func save_snapshot() -> void:
	if busy: return
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		status.text = "Save failed: " + str(FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(snapshot()))
	f.close()
	status.text = "Saved world, compiled-source input and dialogue cursor."

func load_snapshot() -> bool:
	if not FileAccess.file_exists(save_path): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or data.get("schema") != 1: return false
	if not apply_source(data.source): return false
	cue = data.cue
	hour = int(data.hour)
	steam_on = data.steam_on
	rescued = data.rescued
	guest_arrival = int(data.guest_arrival)
	chatter_position = float(data.chatter_position)
	guest_position = float(data.guest_position)
	known_procedure = data.known_procedure
	log_lines.assign(data.log)
	status.text = "Restored exact snapshot; no prior command rerun."
	_refresh()
	return true

func reset_loop() -> void:
	hour = 4
	steam_on = true
	rescued = false
	guest_arrival = 4
	chatter_position = 0.0
	guest_position = 0.0
	cue = "start"
	log_lines.clear()
	status.text = "Probe loop reset. Edited content and learned procedure retained."
	_refresh()

func check(name: String, passed: bool) -> void:
	test_results.append({"name": name, "passed": passed})
	print("PROBE_CHECK ", name, " ", passed)

func _run_tests() -> void:
	reset_loop()
	check("runtime_compile", dialogue != null)
	check("scene_ineligible_before_rescue", await next_line() == "")
	stop_steam()
	check("character_escape", rescued and chatter_position == 1.0)
	check("first_character_line", (await next_line()).contains("Chatterbox:"))
	save_snapshot()
	check("second_character_and_world_command", (await next_line()).contains("Guest:") and guest_arrival == 5)
	check("restore_mid_conversation", load_snapshot() and guest_arrival == 4 and hour == 4)
	check("resume_runs_pending_command_once", (await next_line()).contains("Guest:") and guest_arrival == 5)
	save_snapshot()
	advance_time()
	check("restore_after_mutation", load_snapshot() and guest_arrival == 5 and hour == 4)
	await next_line()
	check("completed_mutation_not_repeated", guest_arrival == 5)
	var edited := DEFAULT_SOURCE.replace("Thank you for stopping the steam.", "LIVE EDIT ACCEPTED").replace("delay_guest(1)", "delay_guest(2)")
	check("live_apply", apply_source(edited))
	reset_loop()
	stop_steam()
	check("edited_line_runs", (await next_line()).contains("LIVE EDIT ACCEPTED"))
	await next_line()
	check("edited_command_changes_world", guest_arrival == 6)
	var before := applied_source
	check("invalid_edit_rejected", not apply_source("~ start\ndo delay_guest(\nGuest: broken\n=> END"))
	check("working_source_retained", applied_source == before)
	save_snapshot()
	reset_loop()
	check("loop_reset_world", steam_on and not rescued and hour == 4 and guest_arrival == 4)
	check("loop_retains_knowledge_and_edits", known_procedure and applied_source == edited)
	check("save_reload_edited_source", load_snapshot() and applied_source == edited and guest_arrival == 6)
	var passed := test_results.all(func(x): return x.passed)
	var report := {"passed": passed, "platform": OS.get_name(), "checks": test_results, "godot": Engine.get_version_info().string, "dialogue_manager": "4.1.0"}
	var encoded := JSON.stringify(report)
	print("PROBE_RESULT ", encoded)
	status.text = "AUTOMATED PROBE: " + ("PASS" if passed else "FAIL") + " — " + str(test_results.size()) + " checks"
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.probeResult = " + encoded + "; document.body.dataset.probeResult = " + JSON.stringify(encoded) + ";")
	else:
		var output_path := "user://probe_results.json"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--report="): output_path = arg.trim_prefix("--report=")
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		file.store_string(encoded)
		file.close()
		get_tree().quit(0 if passed else 1)
