extends Control

const Simulation = preload("res://foundation/run.gd")
const AuthoringSession = preload("res://foundation/authoring_session.gd")
const Benchmark = preload("res://foundation/benchmark.gd")
const AuthoringDocument = preload("res://foundation/authoring_document.gd")
const ProjectAssets = preload("res://foundation/project_assets.gd")
const RoomGeometry = preload("res://foundation/room_geometry.gd")
const AuthoringStore = preload("res://foundation/authoring_store.gd")
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
var suppress_source_signal := false
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
var background_textures: Dictionary = {}
var geometry_mode := ""
var geometry_start := Vector2.ZERO
var geometry_region := -1
var image_dialog: FileDialog
var web_file_callback: JavaScriptObject

func _ready() -> void:
	var authoring_seed_requested := "--authoring-seed" in OS.get_cmdline_user_args()
	var authoring_verify_requested := "--authoring-verify" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		authoring_seed_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('authoring_seed')"))
		authoring_verify_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('authoring_verify')"))
	var authoring_test_mode := authoring_seed_requested or authoring_verify_requested
	simulation = Simulation.new()
	for actor_id in ACTOR_ART:
		actor_frames[actor_id] = CharacterSprite.make_frames(ACTOR_ART[actor_id])
	simulation.attach_journal(("user://foundation_authoring_smoke_run.jsonl" if OS.has_feature("web") else "res://build/foundation_authoring_smoke_run.jsonl") if authoring_test_mode else "user://foundation_run_v2.jsonl")
	var save_path: String = simulation.journal.path
	var has_new_save := FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak") or FileAccess.file_exists(save_path + ".next")
	var prior_foundation_save := FileAccess.file_exists("user://foundation_run.jsonl")
	if has_new_save:
		var loaded := simulation.load_saved()
		if not loaded.ok:
			save_enabled = false
	session = AuthoringSession.new(simulation)
	document = session.document
	authoring_store = AuthoringStore.new(("user://foundation_authoring_smoke.json" if OS.has_feature("web") else "res://build/foundation_authoring_smoke.json") if authoring_test_mode else "user://foundation_authoring.json")
	var authored := AuthoringStore.load(authoring_store.path)
	if authored.ok:
		if not document.restore(authored.data):
			authoring_save_enabled = false
	elif str(authored.reason) != "No authoring draft found":
		authoring_save_enabled = false
	authoring_timer = Timer.new()
	authoring_timer.one_shot = true
	authoring_timer.wait_time = 0.5
	authoring_timer.timeout.connect(_save_authoring)
	add_child(authoring_timer)
	document.changed.connect(_schedule_authoring_save)
	_build_ui()
	if not save_enabled:
		status_label.text = "Save unavailable: existing save invalid. It was not overwritten."
	if not authoring_save_enabled:
		status_label.text = "Authoring draft is corrupt or unavailable. Original files were not overwritten."
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
	if authoring_seed_requested:
		call_deferred("_run_authoring_seed")
	if authoring_verify_requested:
		call_deferred("_run_authoring_verify")

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
	_button(controls, "Return to live", _return_live)
	_button(controls, "Resume from here", _resume_from_here)
	_button(controls, "Retry save", _retry_save)
	_button(controls, "Rewind / skip (R)", _reset_pressed)
	_button(controls, "Undo edit", _undo_edit)
	_button(controls, "Redo edit", _redo_edit)
	_button(controls, "Retry draft save", _retry_authoring_save)
	_button(controls, "Import room background", _import_background)
	_button(controls, "New room", _create_room)
	_button(controls, "Draw walkable", func(): _set_geometry_mode("draw"))
	_button(controls, "Move walkable", func(): _set_geometry_mode("move"))
	_button(controls, "Erase walkable", func(): _set_geometry_mode("erase"))
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
	var rooms: Array = document.content.rooms if session.paused else simulation.content.rooms
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

func _shown_content(shown: Dictionary) -> Dictionary:
	if session.viewed_tick >= 0:
		return simulation.content_versions.get(shown.content_version, simulation.content)
	return document.content if session.paused else simulation.content

func _local_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if simulation.dialogue_available():
		choices.append({"kind": "dialogue", "id": "chatterbox", "label": "Talk"})
	for interaction in simulation.available_interactions():
		choices.append({"kind": "action", "id": interaction.id, "label": interaction.label})
	return choices

func _pause() -> void:
	session.pause()
	_show_source(document.source_draft)
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
	geometry_mode = ""
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
	_show_source(document.source_draft)
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
	status_label.text = "Redid: " + label

func _show_source(source: String) -> void:
	suppress_source_signal = true
	source_editor.text = source
	suppress_source_signal = false

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

func _retry_authoring_save() -> void:
	authoring_save_enabled = true
	_save_authoring()

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
	status_label.text = "%s walkable geometry in %s. Drag on the room view." % [mode.capitalize(), inspected_room]

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
	var invalid_source := "~ start\ndo unfinished("
	document.set_source(invalid_source)
	var content_change := document.content.duplicate(true)
	content_change.rooms.append({"id": "gallery", "name": "Gallery", "bounds": [0, 0, 440, 280], "walkable": [[0, 0, 440, 280]]})
	document.replace_content(content_change, "Create gallery")
	document.undo()
	var saved := authoring_store.save(document)
	var report := {"passed": saved.ok, "reason": saved.reason, "platform": OS.get_name()}
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
	var report := {"passed": document.source_draft.contains("unfinished(") and before.undo_stack.size() == 1 and before.redo_stack.size() == 1 and label == "Create gallery" and document.content.rooms.size() == 3, "platform": OS.get_name(), "redo_label": label}
	var encoded := JSON.stringify(report)
	print("AUTHORING_REOPEN ", encoded)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.body.dataset.authoringReopen = " + JSON.stringify(encoded) + ";")
	else:
		get_tree().quit(0 if report.passed else 1)
