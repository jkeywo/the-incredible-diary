extends Control

const Simulation = preload("res://foundation/run.gd")
const AuthoringSession = preload("res://foundation/authoring_session.gd")
const Benchmark = preload("res://foundation/benchmark.gd")
const AuthoringDocument = preload("res://foundation/authoring_document.gd")
const ProjectAssets = preload("res://foundation/project_assets.gd")
const RoomGeometry = preload("res://foundation/room_geometry.gd")
const AuthoringStore = preload("res://foundation/authoring_store.gd")
const Content = preload("res://foundation/content.gd")
const Inspector = preload("res://foundation/inspector.gd")
const CharacterSprite = preload("res://assets/characters/character_sprite.gd")
const ValveSheet = preload("res://assets/props/valve_states.png")
const ACTOR_ART := {"amelia": "player", "chatterbox": "matron", "guest": "rake"}
const ACTOR_LABELS := {"amelia": "Amelia", "chatterbox": "Chatter Box", "guest": "Guest"}
var simulation: FoundationRun
var session: FoundationAuthoringSession
var document: FoundationAuthoringDocument
var authoring_store: FoundationAuthoringStore
var authoring_timer: Timer
var authoring_save_enabled := true
var authoring_web_sync_pending := false
var suppress_source_signal := false
var save_enabled := true
var accumulator := 0.0
var inspected_room := "service"
var status_label: Label
var state_label: Label
var inspector_label: Label
var canvas: Control
var queued_interaction := ""
var queued_cancel := false
var queued_dialogue_id := ""
var queued_dialogue_advance := false
var wheel_selection := 0
var scrubber: HSlider
var source_editor: CodeEdit
var scenario_source_editor: CodeEdit
var suppress_scenario_signal := false
var storylet_scene_editor: CodeEdit
var suppress_storylet_scene_signal := false
var rewinding := false
var rewind_tick := 0
var actor_frames: Dictionary = {}
var facing_history: Dictionary = {}
var background_textures: Dictionary = {}
var geometry_mode := ""
var geometry_start := Vector2.ZERO
var geometry_region := -1
var pending_connection: Dictionary = {}
var interaction_label_edit: LineEdit
var interaction_duration_edit: SpinBox
var interaction_effect_edit: OptionButton
var interaction_effect_ticks_edit: SpinBox
var actor_id_edit: LineEdit
var actor_sprite_edit: OptionButton
var commitment_id_edit: LineEdit
var commitment_speed_edit: SpinBox
var schedule_timeline: HSlider
var storylet_id_edit: LineEdit
var scene_id_edit: LineEdit
var required_actor_edit: LineEdit
var storylet_start_edit: SpinBox
var storylet_end_edit: SpinBox
var storylet_flag_edit: OptionButton
var image_dialog: FileDialog
var web_file_callback: JavaScriptObject

func _ready() -> void:
	var authoring_seed_requested := "--authoring-seed" in OS.get_cmdline_user_args()
	var authoring_verify_requested := "--authoring-verify" in OS.get_cmdline_user_args()
	var authoring_failure_requested := false
	if OS.has_feature("web"):
		authoring_seed_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('authoring_seed')"))
		authoring_verify_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('authoring_verify')"))
		authoring_failure_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('authoring_failure_smoke')"))
	var authoring_test_mode := authoring_seed_requested or authoring_verify_requested or authoring_failure_requested
	var smoke_directory := "user://" if OS.has_feature("web") else OS.get_executable_path().get_base_dir() + "/"
	simulation = Simulation.new()
	simulation.attach_journal(smoke_directory + "foundation_authoring_smoke_run.jsonl" if authoring_test_mode else "user://foundation_run_v2.jsonl")
	var save_path: String = simulation.journal.path
	var has_new_save := FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak") or FileAccess.file_exists(save_path + ".next")
	var prior_foundation_save := FileAccess.file_exists("user://foundation_run.jsonl")
	if has_new_save:
		var loaded := simulation.load_saved()
		if not loaded.ok:
			save_enabled = false
	session = AuthoringSession.new(simulation)
	document = session.document
	authoring_store = AuthoringStore.new(smoke_directory + "foundation_authoring_smoke.json" if authoring_test_mode else "user://foundation_authoring.json")
	var authored := AuthoringStore.load(authoring_store.path)
	var authoring_recovery_notice := ""
	if authored.ok:
		if not document.restore(authored.data):
			authoring_save_enabled = false
		else:
			if str(authored.source) != authoring_store.path:
				authoring_recovery_notice = str(authored.reason) + ". Review the recovered draft before continuing."
			document.reconcile_runtime(simulation.content)
			if document.recovery_conflict:
				authoring_recovery_notice = "Recovered draft differs from the saved run. Pause to review it, then choose Allow recovered draft."
	elif str(authored.reason) != "No authoring draft found":
		authoring_save_enabled = false
	authoring_timer = Timer.new()
	authoring_timer.one_shot = true
	authoring_timer.wait_time = 0.5
	authoring_timer.timeout.connect(_save_authoring)
	add_child(authoring_timer)
	document.changed.connect(_schedule_authoring_save)
	document.changed.connect(_sync_scenario_source)
	document.changed.connect(_sync_storylet_scene_source)
	_build_ui()
	if not save_enabled:
		status_label.text = "Save unavailable: existing save invalid. It was not overwritten."
	if not authoring_save_enabled:
		status_label.text = "Authoring draft is corrupt or unavailable. Original files were not overwritten."
	else:
		_save()
		if prior_foundation_save and not has_new_save:
			status_label.text = "Fresh foundation run. The previous save file remains untouched."
	if not authoring_recovery_notice.is_empty():
		status_label.text = authoring_recovery_notice
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
	if authoring_seed_requested:
		call_deferred("_run_authoring_seed")
	if authoring_verify_requested:
		call_deferred("_run_authoring_verify")
	if authoring_failure_requested:
		call_deferred("_run_authoring_failure_smoke")

func _process(delta: float) -> void:
	_check_authoring_web_sync()
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
		if not queued_dialogue_id.is_empty():
			command.start_dialogue = queued_dialogue_id
			queued_dialogue_id = ""
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
				if choices[selection].kind == "dialogue": queued_dialogue_id = str(choices[selection].id)
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
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.custom_minimum_size = Vector2(900, 350)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.draw.connect(_draw_world)
	canvas.gui_input.connect(_on_canvas_input)
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
	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.custom_minimum_size.y = 105
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(inspector_scroll)
	inspector_label = Label.new()
	inspector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_scroll.add_child(inspector_label)
	_button(controls, "Return to live", _return_live)
	_button(controls, "Resume from here", _resume_from_here)
	_button(controls, "Retry save", _retry_save)
	_button(controls, "Rewind / skip (R)", _reset_pressed)
	_button(controls, "Undo edit", _undo_edit)
	_button(controls, "Redo edit", _redo_edit)
	_button(controls, "Retry draft save", _retry_authoring_save)
	_button(controls, "Allow recovered draft", _allow_recovered_draft)
	_button(controls, "Import room background", _import_background)
	_button(controls, "New room", _create_room)
	_button(controls, "Draw walkable", func(): _set_geometry_mode("draw"))
	_button(controls, "Move walkable", func(): _set_geometry_mode("move"))
	_button(controls, "Erase walkable", func(): _set_geometry_mode("erase"))
	_button(controls, "Connect door", func(): _set_geometry_mode("door_start"))
	_button(controls, "Move door endpoint", func(): _set_geometry_mode("door_move"))
	_button(controls, "Remove door", func(): _set_geometry_mode("door_remove"))
	_button(controls, "Place interaction", func(): _set_geometry_mode("interaction"))
	interaction_label_edit = LineEdit.new()
	interaction_label_edit.text = "Turn valve"
	interaction_label_edit.placeholder_text = "Interaction label"
	interaction_label_edit.custom_minimum_size.x = 135
	controls.add_child(interaction_label_edit)
	interaction_duration_edit = SpinBox.new()
	interaction_duration_edit.min_value = 1
	interaction_duration_edit.max_value = 1800
	interaction_duration_edit.value = 30
	interaction_duration_edit.suffix = "ticks"
	controls.add_child(interaction_duration_edit)
	interaction_effect_edit = OptionButton.new()
	interaction_effect_edit.add_item("Close valve")
	interaction_effect_edit.add_item("Delay guest")
	controls.add_child(interaction_effect_edit)
	interaction_effect_ticks_edit = SpinBox.new()
	interaction_effect_ticks_edit.min_value = 1
	interaction_effect_ticks_edit.max_value = 1800
	interaction_effect_ticks_edit.value = 60
	interaction_effect_ticks_edit.suffix = "delay ticks"
	controls.add_child(interaction_effect_ticks_edit)
	actor_id_edit = LineEdit.new()
	actor_id_edit.placeholder_text = "Actor ID"
	actor_id_edit.custom_minimum_size.x = 90
	controls.add_child(actor_id_edit)
	actor_sprite_edit = OptionButton.new()
	for sprite_id in CharacterSprite.CHARACTERS:
		actor_sprite_edit.add_item(sprite_id)
	actor_sprite_edit.select(1)
	controls.add_child(actor_sprite_edit)
	_button(controls, "Place actor", func(): _set_geometry_mode("actor"))
	commitment_id_edit = LineEdit.new()
	commitment_id_edit.placeholder_text = "Commitment ID"
	commitment_id_edit.custom_minimum_size.x = 120
	controls.add_child(commitment_id_edit)
	commitment_speed_edit = SpinBox.new()
	commitment_speed_edit.min_value = 0.1
	commitment_speed_edit.max_value = 40
	commitment_speed_edit.step = 0.1
	commitment_speed_edit.value = 4
	commitment_speed_edit.suffix = "units/tick"
	controls.add_child(commitment_speed_edit)
	_button(controls, "Schedule target", func(): _set_geometry_mode("schedule"))
	schedule_timeline = HSlider.new()
	schedule_timeline.min_value = 1
	schedule_timeline.max_value = Simulation.LEG_TICKS
	schedule_timeline.step = 1
	schedule_timeline.value = 20
	schedule_timeline.custom_minimum_size.x = 240
	schedule_timeline.drag_ended.connect(func(changed: bool):
		if changed: _move_commitment_on_timeline(commitment_id_edit.text.strip_edges(), int(schedule_timeline.value)))
	controls.add_child(schedule_timeline)
	storylet_id_edit = LineEdit.new()
	storylet_id_edit.placeholder_text = "Storylet ID"
	storylet_id_edit.custom_minimum_size.x = 105
	storylet_id_edit.text_changed.connect(func(_text: String): _sync_storylet_form())
	controls.add_child(storylet_id_edit)
	scene_id_edit = LineEdit.new()
	scene_id_edit.placeholder_text = "Scene ID"
	scene_id_edit.custom_minimum_size.x = 90
	scene_id_edit.text_changed.connect(func(_text: String): _sync_storylet_scene_source())
	controls.add_child(scene_id_edit)
	required_actor_edit = LineEdit.new()
	required_actor_edit.placeholder_text = "Required actor IDs"
	required_actor_edit.custom_minimum_size.x = 135
	controls.add_child(required_actor_edit)
	storylet_start_edit = SpinBox.new()
	storylet_start_edit.max_value = Simulation.LEG_TICKS
	storylet_start_edit.suffix = "from tick"
	controls.add_child(storylet_start_edit)
	storylet_end_edit = SpinBox.new()
	storylet_end_edit.max_value = Simulation.LEG_TICKS
	storylet_end_edit.value = Simulation.LEG_TICKS
	storylet_end_edit.suffix = "through tick"
	controls.add_child(storylet_end_edit)
	storylet_flag_edit = OptionButton.new()
	storylet_flag_edit.add_item("Any valve state")
	storylet_flag_edit.add_item("Valve closed")
	storylet_flag_edit.add_item("Valve open")
	controls.add_child(storylet_flag_edit)
	_button(controls, "Save storylet", _save_storylet)
	image_dialog = FileDialog.new()
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	image_dialog.use_native_dialog = true
	image_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp", "Images")
	image_dialog.file_selected.connect(_on_native_image)
	add_child(image_dialog)
	source_editor = CodeEdit.new()
	source_editor.text = document.source_draft
	source_editor.text_changed.connect(_on_source_text_changed)
	source_editor.focus_exited.connect(_on_source_focus_exited)
	source_editor.custom_minimum_size.y = 110
	source_editor.visible = false
	column.add_child(source_editor)
	scenario_source_editor = CodeEdit.new()
	scenario_source_editor.text = document.scenario_draft
	scenario_source_editor.text_changed.connect(_on_scenario_source_changed)
	scenario_source_editor.focus_exited.connect(func(): document.finish_scenario_group())
	scenario_source_editor.custom_minimum_size.y = 150
	scenario_source_editor.visible = false
	column.add_child(scenario_source_editor)
	storylet_scene_editor = CodeEdit.new()
	storylet_scene_editor.text_changed.connect(_on_storylet_scene_changed)
	storylet_scene_editor.focus_exited.connect(func(): document.finish_scene_group())
	storylet_scene_editor.custom_minimum_size.y = 100
	storylet_scene_editor.visible = false
	column.add_child(storylet_scene_editor)
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
	var rooms: Array = _shown_content(_shown_state()).rooms
	if rooms.is_empty():
		return
	var index := -1
	for i in rooms.size():
		if rooms[i].id == inspected_room:
			index = i
			break
	inspected_room = str(rooms[(index + 1) % rooms.size()].id)
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
	var shown_content := _shown_content(shown)
	var room := _room_in(shown_content, inspected_room)
	if not room.is_empty():
		var background_id := str(room.get("background_asset", ""))
		if not background_id.is_empty() and shown_content.get("assets", {}).has(background_id):
			if not background_textures.has(background_id):
				background_textures[background_id] = ProjectAssets.texture(shown_content.assets[background_id])
			if background_textures[background_id] != null:
				canvas.draw_texture_rect(background_textures[background_id], Rect2(20, 20, 880, 280), false)
		if session.paused and session.viewed_tick < 0:
			for values in RoomGeometry.rectangles(room):
				var top_left := _world_to_canvas(room, Vector2(float(values[0]), float(values[1])))
				var bottom_right := _world_to_canvas(room, Vector2(float(values[0]) + float(values[2]), float(values[1]) + float(values[3])))
				var rect := Rect2(top_left, bottom_right - top_left)
				canvas.draw_rect(rect, Color(0.35, 0.75, 0.55, 0.15))
				canvas.draw_rect(rect, Color("75d9ad"), false, 2.0)
			for definition in document.content.actors:
				if definition.room == inspected_room:
					var marker := _world_to_canvas(room, Vector2(float(definition.x), float(definition.y)))
					canvas.draw_circle(marker, 5, Color("86b4ee"))
			for commitment in document.content.commitments:
				if commitment.room == inspected_room:
					var marker := _world_to_canvas(room, Vector2(float(commitment.x), float(commitment.get("y", 160.0))))
					canvas.draw_circle(marker, 6, Color("e8a6d0"))
					canvas.draw_string(ThemeDB.fallback_font, marker + Vector2(8, -8), "%s @ %d" % [commitment.id, int(commitment.at_tick)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, Vector2(35, 50), inspected_room.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	for actor_id in shown.actors:
		var actor: Dictionary = shown.actors[actor_id]
		if actor.room != inspected_room:
			continue
		var point := _world_to_canvas(room, Vector2(float(actor.x), float(actor.y)))
		_draw_actor(actor_id, shown, before, point)
		canvas.draw_string(font, point + Vector2(-28, -54), ACTOR_LABELS.get(actor_id, actor_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	for interaction in shown_content.interactions:
		if interaction.room == inspected_room:
			var point := _world_to_canvas(room, Vector2(float(interaction.x), float(interaction.y)))
			if interaction.id == "valve":
				var source_x := 32 if shown.flags.get("close_valve", false) else 0
				canvas.draw_texture_rect_region(ValveSheet, Rect2(point - Vector2(16, 48), Vector2(32, 48)), Rect2(source_x, 0, 32, 48))
			else:
				canvas.draw_rect(Rect2(point - Vector2(8, 8), Vector2(16, 16)), Color("cf7985"))
			canvas.draw_string(font, point + Vector2(-20, 32), interaction.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
	for connection in shown_content.connections:
		for side in ["from", "to"]:
			if connection[side] != inspected_room:
				continue
			var door_point := _world_to_canvas(room, Vector2(float(connection.get(side + "_x")), float(connection.get(side + "_y", 160.0))))
			canvas.draw_circle(door_point, 10, Color("e5c279"))
			canvas.draw_string(font, door_point + Vector2(8, -20), str(connection.id), HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	if session.viewed_tick < 0 and inspected_room == simulation.state.actors.amelia.room:
		var amelia: Dictionary = simulation.state.actors.amelia
		var center := _world_to_canvas(room, Vector2(float(amelia.x), float(amelia.y)))
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
	var art_id := str(ACTOR_ART.get(actor_id, "rake"))
	var historical_content: Dictionary = simulation.content_versions.get(shown.content_version, simulation.content)
	for definition in historical_content.actors:
		if definition.id == actor_id:
			art_id = str(definition.get("sprite", art_id))
			break
	if not actor_frames.has(art_id):
		actor_frames[art_id] = CharacterSprite.make_frames(art_id)
	var frames: SpriteFrames = actor_frames[art_id]
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
	state_label.text = "Tick %d / %d  |  Hour %d  |  %s  |  Viewing: %s  |  Valve: %s" % [shown.tick, simulation.state.tick, mini(6, 1 + int(shown.tick / Simulation.TICKS_PER_HOUR)), "PAUSED" if session.paused else "RUNNING", inspected_room, "closed" if shown.flags.get("close_valve", false) else "open"]
	if is_instance_valid(inspector_label):
		inspector_label.text = Inspector.describe(shown, inspected_room)
	if is_instance_valid(scrubber):
		scrubber.max_value = simulation.state.tick
		if session.viewed_tick < 0:
			scrubber.set_value_no_signal(simulation.state.tick)
	canvas.queue_redraw()

func _shown_state() -> Dictionary:
	return session.inspect()

func _shown_content(shown: Dictionary) -> Dictionary:
	if session.viewed_tick >= 0:
		return simulation.content_versions.get(shown.content_version, simulation.content)
	return document.content if session.paused else simulation.content

func _local_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for storylet in simulation.available_storylets():
		choices.append({"kind": "dialogue", "id": storylet.id, "label": storylet.label})
	for interaction in simulation.available_interactions():
		choices.append({"kind": "action", "id": interaction.id, "label": interaction.label})
	return choices

func _pause() -> void:
	session.pause()
	_show_source(document.source_draft)
	_show_scenario_source(document.scenario_draft)
	_sync_storylet_scene_source()
	source_editor.visible = true
	scenario_source_editor.visible = true
	storylet_scene_editor.visible = true
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
	geometry_mode = ""
	source_editor.visible = false
	scenario_source_editor.visible = false
	storylet_scene_editor.visible = false
	status_label.text = "Continued from recorded time" if target_tick >= 0 else "Running"
	facing_history.clear()

func _undo_edit() -> void:
	if not session.paused or rewinding:
		return
	document.set_source(source_editor.text)
	var label := document.undo()
	if label.is_empty():
		status_label.text = "No authoring edit to undo."
		return
	_show_source(document.source_draft)
	_show_scenario_source(document.scenario_draft)
	_sync_storylet_scene_source()
	if _room_in(document.content, inspected_room).is_empty():
		inspected_room = str(document.content.rooms[0].id)
	status_label.text = "Undid: " + label

func _redo_edit() -> void:
	if not session.paused or rewinding:
		return
	document.set_source(source_editor.text)
	var label := document.redo()
	if label.is_empty():
		status_label.text = "No authoring edit to redo."
		return
	_show_source(document.source_draft)
	_show_scenario_source(document.scenario_draft)
	_sync_storylet_scene_source()
	status_label.text = "Redid: " + label

func _show_source(source: String) -> void:
	suppress_source_signal = true
	source_editor.text = source
	suppress_source_signal = false

func _show_scenario_source(source: String) -> void:
	if not is_instance_valid(scenario_source_editor):
		return
	suppress_scenario_signal = true
	scenario_source_editor.text = source
	suppress_scenario_signal = false

func _sync_storylet_scene_source() -> void:
	if not is_instance_valid(storylet_scene_editor) or storylet_scene_editor.has_focus():
		return
	var scene_id := scene_id_edit.text.strip_edges() if is_instance_valid(scene_id_edit) else ""
	suppress_storylet_scene_signal = true
	storylet_scene_editor.text = str(document.scene_drafts.get(scene_id, ""))
	suppress_storylet_scene_signal = false

func _on_storylet_scene_changed() -> void:
	if not session.paused or suppress_storylet_scene_signal:
		return
	var scene_id := scene_id_edit.text.strip_edges()
	if scene_id.is_empty():
		status_label.text = "Enter a scene ID before editing its source."
		return
	document.set_scene_source(scene_id, storylet_scene_editor.text)
	if document.scene_errors.has(scene_id):
		status_label.text = "Scene %s: %s" % [scene_id, document.scene_errors[scene_id]]
	_refresh()

func _sync_storylet_form() -> void:
	if not is_instance_valid(storylet_id_edit) or not is_instance_valid(scene_id_edit):
		return
	for storylet in document.content.get("storylets", []):
		if storylet.id == storylet_id_edit.text.strip_edges():
			if not scene_id_edit.has_focus(): scene_id_edit.text = str(storylet.scene)
			if not required_actor_edit.has_focus(): required_actor_edit.text = ", ".join(storylet.required_actors)
			storylet_start_edit.value = int(storylet.start_tick)
			storylet_end_edit.value = int(storylet.end_tick)
			var required: Dictionary = storylet.get("required_flags", {})
			storylet_flag_edit.select(0 if not required.has("close_valve") else 1 if required.close_valve else 2)
			return

func _sync_scenario_source() -> void:
	if is_instance_valid(scenario_source_editor) and not scenario_source_editor.has_focus():
		_show_scenario_source(document.scenario_draft)
	if is_instance_valid(source_editor) and not source_editor.has_focus() and source_editor.text != document.source_draft:
		_show_source(document.source_draft)
	if is_instance_valid(actor_id_edit) and is_instance_valid(actor_sprite_edit):
		for actor in document.content.actors:
			if actor.id == actor_id_edit.text.strip_edges():
				for index in actor_sprite_edit.item_count:
					if actor_sprite_edit.get_item_text(index) == str(actor.get("sprite", ACTOR_ART.get(actor.id, "rake"))):
						actor_sprite_edit.select(index)
						break
	if is_instance_valid(commitment_id_edit) and is_instance_valid(schedule_timeline):
		for commitment in document.content.commitments:
			if commitment.id == commitment_id_edit.text.strip_edges():
				schedule_timeline.set_value_no_signal(float(commitment.at_tick))
				commitment_speed_edit.value = float(commitment.speed)
				break
	_sync_storylet_form()

func _on_scenario_source_changed() -> void:
	if session.paused and not suppress_scenario_signal:
		document.set_scenario_source(scenario_source_editor.text)
		if not document.scenario_error.is_empty():
			status_label.text = "Scenario draft: " + document.scenario_error
		else:
			_show_schedule_warning(actor_id_edit.text.strip_edges())
		_refresh()

func _on_source_text_changed() -> void:
	if session.paused and not suppress_source_signal:
		session.set_draft(source_editor.text)

func _on_source_focus_exited() -> void:
	document.finish_source_group()
	if is_instance_valid(authoring_timer) and authoring_timer.time_left > 0.0:
		authoring_timer.stop()
		_save_authoring()

func _exit_tree() -> void:
	if is_instance_valid(authoring_timer) and authoring_timer.time_left > 0.0:
		authoring_timer.stop()
		_save_authoring()

func _schedule_authoring_save() -> void:
	if authoring_save_enabled and is_instance_valid(authoring_timer):
		authoring_timer.start()

func _save_authoring() -> void:
	if not authoring_save_enabled:
		return
	var result := authoring_store.save(document)
	if not result.ok:
		authoring_save_enabled = false
		if is_instance_valid(status_label):
			status_label.text = "Authoring save failed: " + str(result.reason)
	elif OS.has_feature("web"):
		authoring_web_sync_pending = true

func _check_authoring_web_sync() -> void:
	if not authoring_web_sync_pending:
		return
	var result := AuthoringStore.web_verification()
	if str(result.get("status", "")) == "failed":
		authoring_web_sync_pending = false
		authoring_save_enabled = false
		if is_instance_valid(status_label):
			status_label.text = "Authoring save failed: " + str(result.get("reason", "Browser storage error"))
	elif str(result.get("status", "")) == "saved":
		authoring_web_sync_pending = false

func _retry_authoring_save() -> void:
	authoring_save_enabled = true
	_save_authoring()

func _allow_recovered_draft() -> void:
	if not document.recovery_conflict:
		status_label.text = "No recovered draft conflict is pending."
		return
	if not session.paused:
		_pause()
		status_label.text = "Review the recovered draft in the paused editors, then choose Allow recovered draft again."
		return
	document.allow_recovered_draft()
	status_label.text = "Recovered draft may now be applied when you resume. Validation still runs."

func _room_in(in_content: Dictionary, id: String) -> Dictionary:
	for room in in_content.rooms:
		if room.id == id:
			return room
	return {}

func _create_room() -> void:
	if not session.paused or rewinding:
		status_label.text = "Pause before creating a room."
		return
	document.set_source(source_editor.text)
	var next_content := document.content.duplicate(true)
	var number: int = next_content.rooms.size() + 1
	var room_id := "room_%d" % number
	while not _room_in(next_content, room_id).is_empty():
		number += 1
		room_id = "room_%d" % number
	next_content.rooms.append({"id": room_id, "name": "Room %d" % number, "bounds": [0, 0, 440, 280], "walkable": [[0, 0, 440, 280]]})
	document.replace_content(next_content, "Create room %s" % room_id)
	inspected_room = room_id
	status_label.text = "Created %s. Add its background and walkable regions while paused." % room_id
	_refresh()

func _set_geometry_mode(mode: String) -> void:
	if not session.paused or rewinding:
		status_label.text = "Pause before editing room geometry."
		return
	geometry_mode = mode
	if mode == "door_start":
		pending_connection.clear()
	status_label.text = "%s in %s. Click the room view." % [mode.capitalize().replace("_", " "), inspected_room]

func _canvas_point(local: Vector2) -> Vector2:
	var room := _room_in(document.content, inspected_room)
	var bounds: Array = room.get("bounds", [0, 0, 440, 280])
	return Vector2(float(bounds[0]) + clampf((local.x - 20.0) / 880.0, 0.0, 1.0) * float(bounds[2]), float(bounds[1]) + clampf((local.y - 20.0) / 280.0, 0.0, 1.0) * float(bounds[3]))

func _world_to_canvas(room: Dictionary, point: Vector2) -> Vector2:
	var bounds: Array = room.get("bounds", [0, 0, 440, 280])
	if float(bounds[2]) <= 0.0 or float(bounds[3]) <= 0.0:
		return Vector2(20, 20)
	return Vector2(20.0 + (point.x - float(bounds[0])) / float(bounds[2]) * 880.0, 20.0 + (point.y - float(bounds[1])) / float(bounds[3]) * 280.0)

func _region_at(room: Dictionary, point: Vector2) -> int:
	var regions: Array = room.get("walkable", [])
	for index in range(regions.size() - 1, -1, -1):
		var values: Array = regions[index]
		if Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3])).has_point(point):
			return index
	return -1

func _on_canvas_input(event: InputEvent) -> void:
	if not session.paused or rewinding or geometry_mode.is_empty():
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var point := _canvas_point(event.position)
	var room := _room_in(document.content, inspected_room)
	if room.is_empty():
		return
	if event.pressed and geometry_mode == "door_start":
		pending_connection = {"room": inspected_room, "point": point}
		geometry_mode = "door_finish"
		status_label.text = "Select another room, then click its door endpoint."
		return
	if event.pressed and geometry_mode == "door_finish":
		if pending_connection.is_empty() or pending_connection.room == inspected_room:
			status_label.text = "Select a different room for the paired door."
			return
		var next_content := document.content.duplicate(true)
		var connection_id := "%s_%s" % [pending_connection.room, inspected_room]
		var suffix := 2
		while _connection_in(next_content, connection_id) != {}:
			connection_id = "%s_%s_%d" % [pending_connection.room, inspected_room, suffix]
			suffix += 1
		next_content.connections.append({"id": connection_id, "from": pending_connection.room, "to": inspected_room, "from_x": pending_connection.point.x, "from_y": pending_connection.point.y, "to_x": point.x, "to_y": point.y})
		document.replace_content(next_content, "Connect %s to %s" % [pending_connection.room, inspected_room])
		pending_connection.clear()
		geometry_mode = ""
		status_label.text = "Connected rooms. Resume validates the door endpoints."
		_refresh()
		return
	if event.pressed and geometry_mode == "door_move":
		_move_nearest_door(point)
		return
	if event.pressed and geometry_mode == "door_remove":
		_remove_nearest_door(point)
		return
	if event.pressed and geometry_mode == "interaction":
		_place_interaction(point)
		return
	if event.pressed and geometry_mode == "actor":
		_place_actor(point)
		return
	if event.pressed and geometry_mode == "schedule":
		_place_commitment(point)
		return
	if event.pressed:
		geometry_start = point
		geometry_region = _region_at(room, point)
		if geometry_mode == "erase" and geometry_region >= 0:
			_edit_geometry("Remove walkable region", func(regions: Array): regions.remove_at(geometry_region))
		return
	if geometry_mode == "erase":
		return
	if geometry_mode == "draw":
		var top_left := Vector2(minf(geometry_start.x, point.x), minf(geometry_start.y, point.y))
		var size := (point - geometry_start).abs()
		if size.x >= 4.0 and size.y >= 4.0:
			_edit_geometry("Draw walkable region", func(regions: Array): regions.append([top_left.x, top_left.y, size.x, size.y]))
	elif geometry_mode == "move" and geometry_region >= 0:
		var delta := point - geometry_start
		_edit_geometry("Move walkable region", func(regions: Array):
			var values: Array = regions[geometry_region]
			var bounds: Array = room.bounds
			values[0] = clampf(float(values[0]) + delta.x, float(bounds[0]), float(bounds[0]) + float(bounds[2]) - float(values[2]))
			values[1] = clampf(float(values[1]) + delta.y, float(bounds[1]), float(bounds[1]) + float(bounds[3]) - float(values[3])))

func _edit_geometry(label: String, action: Callable) -> void:
	document.set_source(source_editor.text)
	var next_content := document.content.duplicate(true)
	for room in next_content.rooms:
		if room.id == inspected_room:
			if not room.has("walkable"):
				room.walkable = [room.bounds.duplicate(true)]
			action.call(room.walkable)
			break
	document.replace_content(next_content, label)
	status_label.text = label + ". Resume validates the result."
	_refresh()

func _connection_in(data: Dictionary, id: String) -> Dictionary:
	for connection in data.connections:
		if connection.id == id:
			return connection
	return {}

func _move_nearest_door(point: Vector2) -> void:
	var next_content := document.content.duplicate(true)
	var nearest: Dictionary = {}
	var nearest_side := ""
	var distance := INF
	for connection in next_content.connections:
		for side in ["from", "to"]:
			if connection[side] != inspected_room:
				continue
			var endpoint := Vector2(float(connection.get(side + "_x")), float(connection.get(side + "_y", 160.0)))
			if endpoint.distance_to(point) < distance:
				distance = endpoint.distance_to(point)
				nearest = connection
				nearest_side = side
	if nearest.is_empty():
		status_label.text = "This room has no door endpoint to move."
		return
	nearest[nearest_side + "_x"] = point.x
	nearest[nearest_side + "_y"] = point.y
	document.replace_content(next_content, "Move %s door in %s" % [nearest.id, inspected_room])
	status_label.text = "Moved door endpoint. Resume validates reachability."
	_refresh()

func _remove_nearest_door(point: Vector2) -> void:
	var next_content := document.content.duplicate(true)
	var nearest_index := -1
	var distance := INF
	for index in next_content.connections.size():
		var connection: Dictionary = next_content.connections[index]
		for side in ["from", "to"]:
			if connection[side] != inspected_room:
				continue
			var endpoint := Vector2(float(connection.get(side + "_x")), float(connection.get(side + "_y", 160.0)))
			if endpoint.distance_to(point) < distance:
				distance = endpoint.distance_to(point)
				nearest_index = index
	if nearest_index < 0 or distance > 20.0:
		status_label.text = "Click near a door endpoint to remove it."
		return
	var removed_id := str(next_content.connections[nearest_index].id)
	next_content.connections.remove_at(nearest_index)
	document.replace_content(next_content, "Remove door %s" % removed_id)
	status_label.text = "Removed door. Resume validates remaining routes."
	_refresh()

func _place_interaction(point: Vector2) -> void:
	var next_content := document.content.duplicate(true)
	var effect := "delay_guest" if interaction_effect_edit.selected == 1 else "close_valve"
	var interaction_id := "guest_signal" if effect == "delay_guest" else "valve"
	var placed: Dictionary = {}
	for interaction in next_content.interactions:
		if interaction.id == interaction_id:
			placed = interaction
			break
	if placed.is_empty():
		placed = {"id": interaction_id, "radius": 60.0}
		next_content.interactions.append(placed)
	placed.room = inspected_room
	placed.x = point.x
	placed.y = point.y
	placed.label = interaction_label_edit.text.strip_edges()
	placed.duration_ticks = int(interaction_duration_edit.value)
	placed.effect = effect
	if effect == "delay_guest":
		placed.effect_ticks = int(interaction_effect_ticks_edit.value)
	else:
		placed.erase("effect_ticks")
	document.replace_content(next_content, "Place %s interaction in %s" % [interaction_id, inspected_room])
	status_label.text = "Placed interaction. Resume validates reachability, effect and duration."
	_refresh()

func _place_actor(point: Vector2) -> void:
	var actor_id := actor_id_edit.text.strip_edges()
	if actor_id.is_empty() or actor_id == "amelia":
		status_label.text = "Enter a non-player actor ID before placement."
		return
	var next_content := document.content.duplicate(true)
	var definition: Dictionary = {}
	for actor in next_content.actors:
		if actor.id == actor_id:
			definition = actor
			break
	if definition.is_empty():
		definition = {"id": actor_id}
		next_content.actors.append(definition)
	definition.room = inspected_room
	definition.x = point.x
	definition.y = point.y
	definition.sprite = actor_sprite_edit.get_item_text(actor_sprite_edit.selected)
	document.replace_content(next_content, "Place actor %s" % actor_id)
	status_label.text = "Placed %s. Resume validates actor references." % actor_id
	_refresh()

func _place_commitment(point: Vector2) -> void:
	var commitment_id := commitment_id_edit.text.strip_edges()
	var actor_id := actor_id_edit.text.strip_edges()
	if commitment_id.is_empty() or actor_id.is_empty():
		status_label.text = "Enter an actor ID and commitment ID before scheduling."
		return
	var next_content := document.content.duplicate(true)
	var commitment: Dictionary = {}
	for item in next_content.commitments:
		if item.id == commitment_id:
			commitment = item
			break
	if commitment.is_empty():
		commitment = {"id": commitment_id}
		next_content.commitments.append(commitment)
	commitment.actor = actor_id
	commitment.at_tick = int(schedule_timeline.value)
	commitment.room = inspected_room
	commitment.x = point.x
	commitment.y = point.y
	commitment.speed = float(commitment_speed_edit.value)
	document.replace_content(next_content, "Schedule %s at tick %d" % [commitment_id, int(schedule_timeline.value)])
	status_label.text = "Scheduled %s. Resume validates actor, timing and route." % commitment_id
	_show_schedule_warning(actor_id)
	_refresh()

func _move_commitment_on_timeline(commitment_id: String, at_tick: int) -> void:
	if not session.paused or commitment_id.is_empty():
		return
	var next_content := document.content.duplicate(true)
	for commitment in next_content.commitments:
		if commitment.id == commitment_id:
			commitment.at_tick = at_tick
			document.replace_content(next_content, "Move %s to tick %d" % [commitment_id, at_tick])
			status_label.text = "Moved %s on the schedule." % commitment_id
			_show_schedule_warning(str(commitment.actor))
			_refresh()
			return
	status_label.text = "Commitment %s does not exist; place its target first." % commitment_id

func _show_schedule_warning(actor_id: String) -> void:
	for warning in Content.schedule_warnings(document.candidate()):
		if actor_id.is_empty() or warning.actor == actor_id:
			status_label.text = str(warning.message)
			return

func _save_storylet() -> void:
	if not session.paused or rewinding:
		status_label.text = "Pause before authoring a storylet."
		return
	var storylet_id := storylet_id_edit.text.strip_edges()
	var scene_id := scene_id_edit.text.strip_edges()
	if storylet_id.is_empty() or scene_id.is_empty():
		status_label.text = "Enter both a storylet ID and scene ID."
		return
	var required: Array[String] = []
	for raw_id in required_actor_edit.text.split(","):
		var actor_id := raw_id.strip_edges()
		if not actor_id.is_empty() and not required.has(actor_id):
			required.append(actor_id)
	var next_content := document.content.duplicate(true)
	var entry: Dictionary = {}
	for storylet in next_content.get("storylets", []):
		if storylet.id == storylet_id:
			entry = storylet
			break
	if entry.is_empty():
		entry = {"id": storylet_id}
		next_content.storylets.append(entry)
	entry.scene = scene_id
	entry.label = storylet_id.capitalize()
	entry.room = inspected_room
	entry.required_actors = required
	entry.start_tick = int(storylet_start_edit.value)
	entry.end_tick = int(storylet_end_edit.value)
	entry.required_flags = {}
	if storylet_flag_edit.selected > 0:
		entry.required_flags.close_valve = storylet_flag_edit.selected == 1
	entry.priority = 0
	document.replace_content(next_content, "Save storylet %s" % storylet_id)
	var errors := document.validate()
	status_label.text = "Saved storylet draft; resume checks eligibility." if errors.is_empty() else "Storylet draft: " + "; ".join(errors)
	_refresh()

func _import_background() -> void:
	if not session.paused or rewinding:
		status_label.text = "Pause before importing a room background."
		return
	if OS.has_feature("web"):
		if web_file_callback == null:
			web_file_callback = JavaScriptBridge.create_callback(_on_web_image)
			var window := JavaScriptBridge.get_interface("window")
			window.__diaryImagePicked = web_file_callback
		JavaScriptBridge.eval("(function(){const input=document.createElement('input');input.type='file';input.accept='image/png,image/jpeg,image/webp';input.style.display='none';document.body.appendChild(input);input.onchange=function(){const file=input.files[0];if(!file){input.remove();return;}const reader=new FileReader();reader.onload=function(){window.__diaryImagePicked(file.name,reader.result);input.remove();};reader.readAsDataURL(file);};input.click();})();")
	else:
		image_dialog.popup_centered_ratio()

func _on_native_image(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		status_label.text = "Could not read image: " + path.get_file()
		return
	_accept_image(path.get_file(), bytes)

func _on_web_image(args: Array) -> void:
	if args.size() < 2:
		status_label.text = "Browser image selection failed."
		return
	var encoded := str(args[1])
	if not encoded.contains(","):
		status_label.text = "Browser image data is invalid."
		return
	_accept_image(str(args[0]), Marshalls.base64_to_raw(encoded.get_slice(",", 1)))

func _accept_image(name: String, bytes: PackedByteArray) -> void:
	if not session.paused or rewinding:
		return
	var imported: Dictionary = ProjectAssets.import_image(name, bytes)
	if not imported.ok:
		status_label.text = str(imported.reason)
		return
	document.set_source(source_editor.text)
	var next_content := document.content.duplicate(true)
	if not next_content.has("assets"):
		next_content.assets = {}
	next_content.assets[imported.id] = imported.asset
	for room in next_content.rooms:
		if room.id == inspected_room:
			room.background_asset = imported.id
			break
	document.replace_content(next_content, "Import %s background" % inspected_room)
	background_textures.erase(imported.id)
	status_label.text = "Imported %s for %s. Resume validates the room." % [name, inspected_room]
	canvas.queue_redraw()

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
	scenario_source_editor.visible = false
	storylet_scene_editor.visible = false
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

func _run_authoring_seed() -> void:
	document = AuthoringDocument.new(Simulation.new().content)
	document.change_head("fixture-head")
	var invalid_source := "~ start\ndo unfinished("
	document.set_source(invalid_source)
	var content_change := document.content.duplicate(true)
	var sample_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	sample_image.fill(Color("244060"))
	var imported: Dictionary = ProjectAssets.import_image("gallery.png", sample_image.save_png_to_buffer())
	if not imported.ok:
		push_error("Cannot build authoring smoke image: " + str(imported.reason))
		get_tree().quit(1)
		return
	content_change.assets[imported.id] = imported.asset
	content_change.rooms.append({"id": "gallery", "name": "Gallery", "bounds": [0, 0, 440, 280], "walkable": [[0, 0, 440, 280]], "background_asset": imported.id})
	document.replace_content(content_change, "Create gallery")
	content_change = document.content.duplicate(true)
	content_change.commitments.append({"id": "gallery_visit", "actor": "guest", "at_tick": 160, "room": "gallery", "x": 120.0, "y": 160.0, "speed": 4.0})
	document.replace_content(content_change, "Schedule gallery visit")
	document.set_scene_source("gallery_scene", "~ start\nGuest: I found the gallery.\n=> END")
	document.undo()
	var saved := authoring_store.save(document)
	var report := {"passed": saved.ok and document.undo_stack.size() == 3 and document.redo_stack.size() == 1 and document.source_draft == invalid_source, "reason": saved.reason, "platform": OS.get_name()}
	var encoded := JSON.stringify(report)
	print("AUTHORING_SEED ", encoded)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.body.dataset.authoringSeed = " + JSON.stringify(encoded) + ";")
	else:
		get_tree().quit(0 if report.passed else 1)

func _run_authoring_verify() -> void:
	authoring_save_enabled = false
	var before := document.serialize()
	var label := document.redo()
	var schedule_label := document.undo()
	schedule_label = document.undo()
	var restored_schedule := document.redo()
	var restored_scene := document.redo()
	var gallery: Dictionary = document.content.rooms[2]
	var report := {"passed": document.source_draft.contains("unfinished(") and before.baseline_head == "fixture-head" and before.undo_stack.size() == 3 and before.redo_stack.size() == 1 and label == "Edit scene gallery_scene" and schedule_label == "Schedule gallery visit" and restored_schedule == "Schedule gallery visit" and restored_scene == "Edit scene gallery_scene" and document.content.rooms.size() == 3 and document.content.commitments.size() == 4 and document.content.scenes.has("gallery_scene") and document.content.assets.has(gallery.background_asset) and ProjectAssets.validate(document.content.assets[gallery.background_asset]).is_empty() and simulation.content.rooms.size() == 2, "platform": OS.get_name(), "redo_label": label, "schedule_label": schedule_label}
	var encoded := JSON.stringify(report)
	print("AUTHORING_REOPEN ", encoded)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.body.dataset.authoringReopen = " + JSON.stringify(encoded) + ";")
	else:
		get_tree().quit(0 if report.passed else 1)

func _run_authoring_failure_smoke() -> void:
	if not OS.has_feature("web"):
		return
	authoring_save_enabled = false
	JavaScriptBridge.eval("window.__originalIndexedDbOpen = indexedDB.open; indexedDB.open = () => { throw new DOMException('Denied for test', 'SecurityError'); };")
	AuthoringStore._start_web_verification("/userfs/authoring-denied-test", "0".repeat(64), 9001)
	JavaScriptBridge.eval("indexedDB.open = window.__originalIndexedDbOpen; delete window.__originalIndexedDbOpen;")
	authoring_web_sync_pending = true
	_check_authoring_web_sync()
	var denied_reported := not authoring_save_enabled and status_label.text.contains("Browser storage could not be opened")
	authoring_save_enabled = true
	AuthoringStore._start_web_verification("/userfs/authoring-missing-test", "0".repeat(64), 9002)
	authoring_web_sync_pending = true
	await get_tree().create_timer(5.2).timeout
	_check_authoring_web_sync()
	var timeout_reported := not authoring_save_enabled and status_label.text.contains("check quota or site storage")
	var report := {"passed": denied_reported and timeout_reported, "denied": denied_reported, "missing_durable_record": timeout_reported}
	print("AUTHORING_STORAGE_FAILURE ", JSON.stringify(report))
	JavaScriptBridge.eval("document.body.dataset.authoringStorageFailure = " + JSON.stringify(JSON.stringify(report)) + ";")
