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
const GithubApi = preload("res://foundation/github_api.gd")
const GithubCredentials = preload("res://foundation/github_credentials.gd")
const GithubRepository = preload("res://foundation/github_repository.gd")
const GithubProject = preload("res://foundation/github_project.gd")
const GithubCommit = preload("res://foundation/github_commit.gd")
const GithubSync = preload("res://foundation/github_sync.gd")
const GithubConflict = preload("res://foundation/github_conflict.gd")
const FloatingPanel = preload("res://foundation/floating_panel.gd")
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
var hud: VBoxContainer
var source_tabs: TabContainer
var editor_overlay: Control
var panel_layer: Control
var panel_dock: HBoxContainer
var legacy_controls: HFlowContainer
var editor_menus: Dictionary = {}
var menu_actions: Dictionary = {}
var floating_panels: Dictionary = {}
var next_menu_id := 1
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
var github_api: FoundationGithubApi
var github_credentials: FoundationGithubCredentials
var github_repository: FoundationGithubRepository
var github_writer: FoundationGithubCommit
var github_sync: FoundationGithubSync
var github_conflict: FoundationGithubConflict
var github_panel: FoundationFloatingPanel
var github_token_edit: LineEdit
var github_repo_picker: OptionButton
var github_branch_picker: OptionButton
var github_message_edit: LineEdit
var github_commit_dialog: ConfirmationDialog
var github_conflict_dialog: ConfirmationDialog
var github_comparison_button: Button
var github_review_revision := -1
var github_review_message := ""
var github_auth_generation := 0

func _ready() -> void:
	var authoring_seed_requested := "--authoring-seed" in OS.get_cmdline_user_args()
	var authoring_verify_requested := "--authoring-verify" in OS.get_cmdline_user_args()
	var authoring_failure_requested := false
	var github_integration_test := "--github-integration-test" in OS.get_cmdline_user_args()
	var github_integration_test_b := "--github-integration-test-b" in OS.get_cmdline_user_args()
	var github_storage_seed := false
	var github_storage_verify := false
	if OS.has_feature("web"):
		authoring_seed_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('authoring_seed')"))
		authoring_verify_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('authoring_verify')"))
		authoring_failure_requested = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('authoring_failure_smoke')"))
		github_integration_test = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('github_integration_test')"))
		github_integration_test_b = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('github_integration_test_b')"))
		github_storage_seed = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('github_storage_seed')"))
		github_storage_verify = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('github_storage_verify')"))
	var authoring_test_mode := authoring_seed_requested or authoring_verify_requested or authoring_failure_requested
	var smoke_directory := "user://" if OS.has_feature("web") else OS.get_executable_path().get_base_dir() + "/"
	simulation = Simulation.new()
	simulation.attach_journal(smoke_directory + "foundation_github_integration_b_run.jsonl" if github_integration_test_b else smoke_directory + "foundation_github_integration_run.jsonl" if github_integration_test else smoke_directory + "foundation_authoring_smoke_run.jsonl" if authoring_test_mode else "user://foundation_run_v2.jsonl")
	var save_path: String = simulation.journal.path
	var has_new_save := FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak") or FileAccess.file_exists(save_path + ".next")
	var prior_foundation_save := FileAccess.file_exists("user://foundation_run.jsonl")
	if has_new_save:
		var loaded := simulation.load_saved()
		if not loaded.ok:
			save_enabled = false
	session = AuthoringSession.new(simulation)
	document = session.document
	authoring_store = AuthoringStore.new(smoke_directory + "foundation_github_integration_b_authoring.json" if github_integration_test_b else smoke_directory + "foundation_github_integration_authoring.json" if github_integration_test else smoke_directory + "foundation_authoring_smoke.json" if authoring_test_mode else "user://foundation_authoring.json")
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
	github_credentials = GithubCredentials.new()
	github_api = GithubApi.new()
	github_api.access_token = github_credentials.load_token()
	add_child(github_api)
	github_repository = GithubRepository.new(github_api)
	github_writer = GithubCommit.new(github_api)
	github_sync = GithubSync.new(github_repository)
	github_conflict = GithubConflict.new(github_api)
	_build_ui()
	document.changed.connect(_sync_github_handoff)
	_sync_github_handoff()
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
	if github_storage_seed or github_storage_verify:
		call_deferred("_run_github_storage_smoke", github_storage_seed)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--github-native-smoke=") and not OS.has_feature("web"):
			call_deferred("_run_github_native_smoke", argument.trim_prefix("--github-native-smoke="))
	if OS.has_feature("web") and github_integration_test:
		var github_web_smoke: String = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('github_web_smoke') || ''"))
		if not github_web_smoke.is_empty():
			call_deferred("_run_github_web_smoke", github_web_smoke)

func _run_github_web_smoke(mode: String) -> void:
	var report := {"passed": false, "mode": mode, "platform": OS.get_name(), "browser_user_agent": str(JavaScriptBridge.eval("navigator.userAgent"))}
	if mode != "read":
		report.reason = "Unsupported hosted smoke mode"
	elif github_api.access_token.is_empty():
		report.reason = "No token saved for this browser origin"
	else:
		var repository := "jkeywo/the-incredible-diary"
		var branch := "codex/sync-integration-test"
		var opened: Dictionary = await github_repository.open_project(repository, branch)
		if not opened.ok:
			report.reason = str(opened.reason)
		else:
			report.head = str(opened.head)
			report.asset_count = opened.content.assets.size()
			report.passed = true
	var encoded := JSON.stringify(report)
	print("GITHUB_WEB_SMOKE ", encoded)
	JavaScriptBridge.eval("document.body.dataset.githubWebSmoke = " + JSON.stringify(encoded) + ";")

func _run_github_storage_smoke(seed: bool) -> void:
	var store := GithubCredentials.new("user://unused_github_storage_smoke.json", "the-incredible-diary.github-storage-smoke.v1")
	var passed := false
	if seed:
		passed = bool(store.save_token("test-only-token").ok) and store.load_token() == "test-only-token"
	else:
		passed = store.load_token() == "test-only-token" and bool(store.clear_token().ok) and store.load_token().is_empty()
	JavaScriptBridge.eval("document.body.dataset.githubStorage = %s" % JSON.stringify("passed" if passed else "failed"))
	print("GITHUB_STORAGE_RESULT ", JSON.stringify({"passed": passed, "phase": "seed" if seed else "verify"}))

func _run_github_native_smoke(mode: String) -> void:
	var report := {"passed": false, "mode": mode}
	if mode != "read" and mode != "commit-asset" and mode != "commit-dialogue":
		report.reason = "Unknown mode"
	elif github_api.access_token.is_empty():
		report.reason = "No saved Windows token"
	else:
		var opened: Dictionary = await github_repository.open_project("jkeywo/the-incredible-diary", "codex/sync-integration-test")
		if not opened.ok:
			report.reason = str(opened.reason)
		elif mode == "read":
			report.passed = true
			report.head = str(opened.head)
			report.asset_count = opened.content.assets.size()
		else:
			var native_document := AuthoringDocument.new(opened.content)
			native_document.checkout_remote("jkeywo/the-incredible-diary", "codex/sync-integration-test", str(opened.head), opened.content)
			if mode == "commit-asset":
				var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
				image.fill(Color("#2e5260"))
				var imported: Dictionary = ProjectAssets.import_image("native-integration-check.png", image.save_png_to_buffer())
				if imported.ok:
					var updated: Dictionary = opened.content.duplicate(true)
					updated.assets[imported.id] = imported.asset
					updated.rooms[0].background_asset = imported.id
					native_document.replace_content(updated, "Windows integration background")
				else:
					report.reason = str(imported.reason)
			else:
				var lines := str(opened.content.dialogue).split("\n")
				if lines.size() > 1:
					lines[1] = "Chatterbox: The guest has arrived."
					native_document.set_source("\n".join(lines))
				else:
					report.reason = "No dialogue line to edit"
			if not report.has("reason"):
				var message := "Test Windows authored asset sync" if mode == "commit-asset" else "Test Windows conflicting dialogue"
				var committed: Dictionary = await github_writer.commit(native_document, "jkeywo/the-incredible-diary", "codex/sync-integration-test", str(opened.head), message)
				report.passed = bool(committed.ok)
				report.head = str(committed.get("head", ""))
				report.asset_count = native_document.candidate().assets.size()
				if not committed.ok:
					report.reason = str(committed.reason)
	print("GITHUB_NATIVE_SMOKE ", JSON.stringify(report))
	get_tree().quit(0 if report.passed else 1)

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
		if rewinding or (session.paused and editor_overlay.visible):
			_reset_pressed()
		return
	if rewinding: return
	if session.paused and editor_overlay.visible and event.is_action_pressed("step_tick"):
		_step_tick()
		return
	if session.paused and editor_overlay.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		_toggle_github_panel()
		return
	if session.paused:
		return
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
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_world)
	canvas.gui_input.connect(_on_canvas_input)
	add_child(canvas)
	var column := VBoxContainer.new()
	column.visible = false
	add_child(column)
	hud = VBoxContainer.new()
	hud.position = Vector2(12, 8)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	state_label = Label.new()
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(state_label)
	status_label = Label.new()
	status_label.text = "WASD / left stick moves Amelia. 1–2 / right stick + X chooses a local action."
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(status_label)
	editor_overlay = Control.new()
	editor_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	editor_overlay.visible = session.paused
	add_child(editor_overlay)
	var menu_background := PanelContainer.new()
	menu_background.anchor_right = 1.0
	menu_background.offset_right = 0.0
	menu_background.offset_left = 58
	menu_background.custom_minimum_size.y = 38
	editor_overlay.add_child(menu_background)
	var menu_row := HBoxContainer.new()
	menu_row.add_theme_constant_override("separation", 10)
	menu_background.add_child(menu_row)
	for caption in ["Run", "Edit", "Room", "Actors", "Storylets", "History", "Project", "View"]:
		_create_menu(menu_row, caption)
	panel_layer = Control.new()
	panel_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	editor_overlay.add_child(panel_layer)
	var dock_background := PanelContainer.new()
	dock_background.anchor_top = 1.0
	dock_background.anchor_bottom = 1.0
	dock_background.anchor_right = 1.0
	dock_background.offset_top = -38.0
	dock_background.offset_bottom = 0.0
	editor_overlay.add_child(dock_background)
	panel_dock = HBoxContainer.new()
	dock_background.add_child(panel_dock)
	var controls := HFlowContainer.new()
	legacy_controls = controls
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
	_button(controls, "GitHub project", _toggle_github_panel)
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
	scenario_source_editor.focus_exited.connect(func(): document.finish_edit_group("scenario"))
	scenario_source_editor.custom_minimum_size.y = 150
	scenario_source_editor.visible = false
	column.add_child(scenario_source_editor)
	storylet_scene_editor = CodeEdit.new()
	storylet_scene_editor.text_changed.connect(_on_storylet_scene_changed)
	storylet_scene_editor.focus_exited.connect(func(): document.finish_edit_group(str(storylet_scene_editor.get_meta("edit_group", "scene:"))))
	storylet_scene_editor.custom_minimum_size.y = 100
	storylet_scene_editor.visible = false
	column.add_child(storylet_scene_editor)
	_build_github_panel()
	_reflow_editor_controls(column, controls, inspector_scroll)

func _button(parent: Node, caption: String, action: Callable) -> void:
	if parent == legacy_controls:
		_menu_action(_menu_for_action(caption), caption, action)
		return
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)

func _create_menu(parent: HBoxContainer, caption: String) -> void:
	var button := MenuButton.new()
	button.text = caption
	parent.add_child(button)
	var popup := button.get_popup()
	popup.id_pressed.connect(func(id: int):
		if session.paused and editor_overlay.visible and menu_actions.has(id):
			menu_actions[id].call())
	editor_menus[caption] = popup

func _menu_action(group: String, caption: String, action: Callable) -> void:
	var id := next_menu_id
	next_menu_id += 1
	menu_actions[id] = action
	(editor_menus[group] as PopupMenu).add_item(caption, id)

func _menu_for_action(caption: String) -> String:
	match caption:
		"Pause / resume (Space)", "Single tick (.)", "Next event", "Return to live", "Resume from here", "Retry save", "Rewind / skip (R)": return "Run"
		"Undo edit", "Redo edit", "Retry draft save", "Allow recovered draft": return "Edit"
		"Import room background", "New room", "Draw walkable", "Move walkable", "Erase walkable", "Connect door", "Move door endpoint", "Remove door", "Place interaction": return "Room"
		"Place actor", "Schedule target": return "Actors"
		"Save storylet": return "Storylets"
		"GitHub project": return "Project"
		_: return "View"

func _make_panel(caption: String, initial_position: Vector2, initial_size: Vector2) -> FoundationFloatingPanel:
	var panel: FoundationFloatingPanel = FloatingPanel.new()
	panel.configure(caption, initial_size)
	panel.position = initial_position
	panel.visible = false
	panel.attach_dock(panel_dock)
	panel_layer.add_child(panel)
	panel_layer.resized.connect(panel.fit_to_parent)
	panel.fit_to_parent()
	floating_panels[caption] = panel
	return panel

func _open_panel(caption: String) -> void:
	if not session.paused or not editor_overlay.visible or not floating_panels.has(caption):
		return
	floating_panels[caption].open_panel()

func _field(parent: VBoxContainer, caption: String, field: Control) -> void:
	var label := Label.new()
	label.text = caption
	parent.add_child(label)
	field.reparent(parent)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _panel_body(panel: FoundationFloatingPanel) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	panel.body.add_child(margin)
	var content := VBoxContainer.new()
	margin.add_child(content)
	return content

func _reflow_editor_controls(column: VBoxContainer, _controls: HFlowContainer, inspector_scroll: ScrollContainer) -> void:
	var history := _panel_body(_make_panel("History", Vector2(60, 64), Vector2(460, 300)))
	scrubber.reparent(history)
	inspector_scroll.reparent(history)
	inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_action("History", "Show history and diagnostics", func(): _open_panel("History"))
	var source_panel := _make_panel("Source editors", Vector2(150, 90), Vector2(590, 430))
	source_tabs = TabContainer.new()
	source_tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	source_panel.body.add_child(source_tabs)
	for source in [source_editor, scenario_source_editor, storylet_scene_editor]:
		source.reparent(source_tabs)
		source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		source.size_flags_vertical = Control.SIZE_EXPAND_FILL
	source_editor.name = "Dialogue"
	scenario_source_editor.name = "Scenario"
	storylet_scene_editor.name = "Scene"
	_menu_action("Edit", "Show source editors", func(): _open_panel("Source editors"))
	var interaction := _panel_body(_make_panel("Interaction settings", Vector2(220, 130), Vector2(330, 380)))
	_field(interaction, "Label", interaction_label_edit)
	_field(interaction, "Duration", interaction_duration_edit)
	_field(interaction, "Effect", interaction_effect_edit)
	_field(interaction, "Delay", interaction_effect_ticks_edit)
	_menu_action("Room", "Show interaction settings", func(): _open_panel("Interaction settings"))
	var actors := _panel_body(_make_panel("Actor and schedule", Vector2(280, 100), Vector2(370, 440)))
	_field(actors, "Actor ID", actor_id_edit)
	_field(actors, "Sprite", actor_sprite_edit)
	_field(actors, "Commitment ID", commitment_id_edit)
	_field(actors, "Speed", commitment_speed_edit)
	_field(actors, "Scheduled tick", schedule_timeline)
	_menu_action("Actors", "Show actor and schedule", func(): _open_panel("Actor and schedule"))
	var storylets := _panel_body(_make_panel("Storylet conditions", Vector2(340, 76), Vector2(370, 480)))
	_field(storylets, "Storylet ID", storylet_id_edit)
	_field(storylets, "Scene ID", scene_id_edit)
	_field(storylets, "Required actor IDs", required_actor_edit)
	_field(storylets, "From tick", storylet_start_edit)
	_field(storylets, "Through tick", storylet_end_edit)
	_field(storylets, "Valve state", storylet_flag_edit)
	_menu_action("Storylets", "Show storylet conditions", func(): _open_panel("Storylet conditions"))
	column.queue_free()
	legacy_controls = null

func _build_github_panel() -> void:
	github_panel = _make_panel("GitHub project", Vector2(180, 100), Vector2(650, 310))
	var rows := _panel_body(github_panel)
	var token_row := HFlowContainer.new()
	rows.add_child(token_row)
	github_token_edit = LineEdit.new()
	github_token_edit.secret = true
	github_token_edit.placeholder_text = "GitHub token for this device"
	github_token_edit.custom_minimum_size.x = 300
	github_token_edit.text = github_api.access_token
	token_row.add_child(github_token_edit)
	_button(token_row, "Save token", _github_save_token)
	_button(token_row, "Remove token", _github_remove_token)
	_button(token_row, "List repositories", _github_list_repositories)
	var project_row := HFlowContainer.new()
	rows.add_child(project_row)
	github_repo_picker = OptionButton.new()
	github_repo_picker.custom_minimum_size.x = 220
	github_repo_picker.add_item("Choose repository")
	github_repo_picker.item_selected.connect(_github_choose_repository)
	project_row.add_child(github_repo_picker)
	github_branch_picker = OptionButton.new()
	github_branch_picker.custom_minimum_size.x = 160
	github_branch_picker.add_item("Choose branch")
	project_row.add_child(github_branch_picker)
	_button(project_row, "Open project", _github_open_project)
	var sync_row := HFlowContainer.new()
	rows.add_child(sync_row)
	github_message_edit = LineEdit.new()
	github_message_edit.placeholder_text = "Commit message"
	github_message_edit.custom_minimum_size.x = 230
	sync_row.add_child(github_message_edit)
	_button(sync_row, "Commit & sync", _github_review_commit)
	_button(sync_row, "Fetch & integrate", _github_fetch_and_integrate)
	github_comparison_button = Button.new()
	github_comparison_button.text = "Open conflict comparison"
	github_comparison_button.visible = not document.conflict_handoff.is_empty()
	github_comparison_button.pressed.connect(_github_open_comparison)
	sync_row.add_child(github_comparison_button)
	github_commit_dialog = ConfirmationDialog.new()
	github_commit_dialog.title = "Commit authored project"
	github_commit_dialog.confirmed.connect(_github_commit_confirmed)
	add_child(github_commit_dialog)
	github_conflict_dialog = ConfirmationDialog.new()
	github_conflict_dialog.title = "Preserve conflicting authoring"
	github_conflict_dialog.dialog_text = "The changes overlap. Save this valid local draft to a separate GitHub branch for comparison and resolution?"
	github_conflict_dialog.confirmed.connect(_github_preserve_conflict)
	add_child(github_conflict_dialog)

func _toggle_github_panel() -> void:
	if github_panel.visible:
		github_panel.close_panel()
		return
	_open_panel("GitHub project")
	if not github_api.access_token.is_empty() and github_repo_picker.item_count <= 1:
		_github_list_repositories()

func _github_save_token() -> void:
	var proposed := github_token_edit.text.strip_edges()
	if proposed.is_empty():
		status_label.text = "Enter a GitHub token."
		return
	github_auth_generation += 1
	var attempt := github_auth_generation
	var verifier := GithubApi.new()
	verifier.access_token = proposed
	add_child(verifier)
	var checked: Dictionary = await verifier.request(HTTPClient.METHOD_GET, "/user")
	verifier.queue_free()
	if attempt != github_auth_generation:
		return
	if github_token_edit.text.strip_edges() != proposed:
		status_label.text = "Token changed during sign-in; save it again."
		return
	if not checked.ok:
		status_label.text = "GitHub sign-in failed: " + str(checked.reason)
		return
	var saved: Dictionary = github_credentials.save_token(proposed)
	status_label.text = str(saved.reason)
	if saved.ok:
		github_api.access_token = proposed
		_github_list_repositories()

func _github_remove_token() -> void:
	github_auth_generation += 1
	var removed: Dictionary = github_credentials.clear_token()
	if removed.ok:
		github_api.access_token = ""
		github_token_edit.clear()
		github_repo_picker.clear()
		github_repo_picker.add_item("Choose repository")
		github_branch_picker.clear()
		github_branch_picker.add_item("Choose branch")
	status_label.text = str(removed.reason)

func _github_list_repositories() -> void:
	if github_api.access_token.is_empty():
		status_label.text = "Enter and save a GitHub token first."
		return
	var listing_auth_generation := github_auth_generation
	var listed: Dictionary = await github_repository.list_repositories()
	if listing_auth_generation != github_auth_generation:
		return
	if not listed.ok:
		status_label.text = "Could not list GitHub repositories: " + str(listed.reason)
		return
	var previous_repository := ""
	if github_repo_picker.selected > 0:
		previous_repository = github_repo_picker.get_item_text(github_repo_picker.selected)
	github_repo_picker.clear()
	github_repo_picker.add_item("Choose repository")
	for item in listed.repositories:
		github_repo_picker.add_item(str(item.full_name))
	var restored := false
	for index in range(1, github_repo_picker.item_count):
		if github_repo_picker.get_item_text(index) == previous_repository:
			github_repo_picker.select(index)
			restored = true
			break
	if not restored:
		github_branch_picker.clear()
		github_branch_picker.add_item("Choose branch")
	status_label.text = "Choose a repository to list its branches."

func _github_choose_repository(index: int) -> void:
	github_branch_picker.clear()
	github_branch_picker.add_item("Choose branch")
	if index == 0:
		return
	var selected := github_repo_picker.get_item_text(index)
	var listing_auth_generation := github_auth_generation
	var listed: Dictionary = await github_repository.list_branches(selected)
	if listing_auth_generation != github_auth_generation or github_repo_picker.selected <= 0 or github_repo_picker.get_item_text(github_repo_picker.selected) != selected:
		return
	if not listed.ok:
		status_label.text = "Could not list GitHub branches: " + str(listed.reason)
		return
	for item in listed.branches:
		github_branch_picker.add_item(str(item.name))
	status_label.text = "Choose a branch containing an Incredible Diary project."

func _github_open_project() -> void:
	if not session.paused:
		status_label.text = "Pause before opening a GitHub project."
		return
	if github_repo_picker.selected <= 0 or github_branch_picker.selected <= 0:
		status_label.text = "Choose a GitHub repository and branch."
		return
	if document.has_protected_work() or document.recovery_conflict:
		status_label.text = "Current local authoring has unsaved changes; keep them before opening another project."
		return
	var full_name := github_repo_picker.get_item_text(github_repo_picker.selected)
	var branch := github_branch_picker.get_item_text(github_branch_picker.selected)
	var opening_document := document
	var opening_revision := document.revision
	var opening_auth_generation := github_auth_generation
	var opened: Dictionary = await github_repository.open_project(full_name, branch)
	if not opened.ok:
		status_label.text = "Could not open GitHub project: " + str(opened.reason)
		return
	if not session.paused or document != opening_document or document.revision != opening_revision or github_auth_generation != opening_auth_generation or github_repo_picker.selected <= 0 or github_branch_picker.selected <= 0 or github_repo_picker.get_item_text(github_repo_picker.selected) != full_name or github_branch_picker.get_item_text(github_branch_picker.selected) != branch:
		status_label.text = "Editor state changed during download; project was not opened."
		return
	document.replace_content(opened.content, "Open GitHub project")
	document.checkout_remote(full_name, branch, str(opened.head), opened.content)
	_refresh()
	status_label.text = "Opened %s on %s at %s" % [full_name, branch, str(opened.head).substr(0, 8)]

func _github_review_commit() -> void:
	if not session.paused or document.remote_origin.is_empty():
		status_label.text = "Pause and open a GitHub project before committing."
		return
	var packaged: Dictionary = GithubProject.package(document)
	if not packaged.ok:
		status_label.text = "Commit blocked: " + str(packaged.reason)
		return
	if github_message_edit.text.strip_edges().is_empty():
		status_label.text = "Enter a commit message."
		return
	var origin: Dictionary = document.remote_origin
	var changed_sections := PackedStringArray()
	for key in ["assets", "rooms", "connections", "actors", "commitments", "interactions", "storylets", "scenes", "dialogue"]:
		if origin.content.get(key) != packaged.scenario.get(key):
			changed_sections.append(key)
	if changed_sections.is_empty():
		status_label.text = "No authored project changes to commit."
		return
	github_review_revision = document.revision
	github_review_message = github_message_edit.text.strip_edges()
	github_commit_dialog.dialog_text = "Repository: %s\nBranch: %s\nChanged: %s\nMessage: %s" % [origin.repository, origin.branch, ", ".join(changed_sections), github_review_message]
	github_commit_dialog.popup_centered()

func _github_commit_confirmed() -> void:
	if document.revision != github_review_revision or github_message_edit.text.strip_edges() != github_review_message:
		status_label.text = "Authoring or commit message changed; review the commit again."
		return
	var origin: Dictionary = document.remote_origin.duplicate(true)
	status_label.text = "Committing authored project to GitHub..."
	var result: Dictionary = await github_writer.commit(document, str(origin.repository), str(origin.branch), str(origin.head), github_review_message)
	if result.ok:
		status_label.text = "Committed at %s%s" % [str(result.head).substr(0, 8), "; newer local edits remain" if result.get("later_edits", false) else ""]
		github_message_edit.clear()
	else:
		status_label.text = "Commit blocked: " + str(result.reason)
	_refresh()

func _github_fetch_and_integrate() -> void:
	if not session.paused or document.remote_origin.is_empty():
		status_label.text = "Pause and open a GitHub project before fetching."
		return
	var fetching_document := document
	var fetching_revision := document.revision
	var fetching_auth_generation := github_auth_generation
	status_label.text = "Fetching GitHub project..."
	var fetched: Dictionary = await github_sync.fetch(document)
	if not fetched.ok:
		status_label.text = "Fetch failed: " + str(fetched.reason)
		return
	if not session.paused or document != fetching_document or document.revision != fetching_revision or github_auth_generation != fetching_auth_generation:
		status_label.text = "Editor state changed during fetch; nothing was integrated."
		return
	var integrated: Dictionary = github_sync.integrate(document, fetched)
	if integrated.ok:
		status_label.text = str(integrated.reason) + ("; local changes still need a commit" if integrated.get("needs_commit", false) else "")
	elif not integrated.get("conflicts", []).is_empty() or not integrated.get("errors", []).is_empty():
		status_label.text = "Authored changes could not be combined; preserve the last valid local work on a separate branch."
		github_conflict_dialog.dialog_text = "The local and remote changes cannot be combined. Save the last valid local authored project to a separate GitHub branch? Any invalid combined draft stays here for correction."
		github_conflict_dialog.popup_centered()
	else:
		status_label.text = "Integration blocked: " + str(integrated.reason)
	_refresh()

func _github_preserve_conflict() -> void:
	status_label.text = "Preserving local authored project on a conflict branch..."
	var result: Dictionary = await github_conflict.preserve(document)
	status_label.text = str(result.reason)

func _github_open_comparison() -> void:
	var url := str(document.conflict_handoff.get("url", ""))
	if url.begins_with("https://github.com/"):
		OS.shell_open(url)

func _sync_github_handoff() -> void:
	if is_instance_valid(github_comparison_button):
		github_comparison_button.visible = not document.conflict_handoff.is_empty()

func _toggle_pause() -> void:
	if session.paused: _resume(false)
	else: _pause()

func toggle_pause_editor() -> void:
	if rewinding:
		return
	_toggle_pause()
	_refresh()
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
	if not session.paused or not editor_overlay.visible:
		return
	session.view_tick(int(value))
	_refresh()

func _return_live() -> void:
	session.return_live()
	_refresh()

func _resume_from_here() -> void:
	_resume(true)
	_refresh()

func _draw_world() -> void:
	var world_scale := _world_scale()
	canvas.draw_set_transform((canvas.size - Vector2(900, 350) * world_scale) * 0.5, 0.0, Vector2.ONE * world_scale)
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
		inspector_label.get_parent().visible = session.paused
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
	hud.position = Vector2(12, 44)
	editor_overlay.show()
	_show_source(document.source_draft)
	_show_scenario_source(document.scenario_draft)
	_sync_storylet_scene_source()
	source_editor.visible = true
	scenario_source_editor.visible = true
	storylet_scene_editor.visible = true
	source_tabs.current_tab = 0
	status_label.text = "Paused. Open tools from the menus; resume validates and applies the draft."

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
	hud.position = Vector2(12, 8)
	editor_overlay.hide()
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
	storylet_scene_editor.set_meta("edit_group", "scene:" + scene_id)
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
		document.set_source(source_editor.text)

func _on_source_focus_exited() -> void:
	document.finish_edit_group("source")
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
	var result := document.create_room()
	if result.ok: inspected_room = str(result.id)
	_show_edit_result(result)

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
	var scale := _world_scale()
	var offset := (canvas.size - Vector2(900, 350) * scale) * 0.5 if is_instance_valid(canvas) else Vector2.ZERO
	var game_point := (local - offset) / scale
	return Vector2(float(bounds[0]) + clampf((game_point.x - 20.0) / 880.0, 0.0, 1.0) * float(bounds[2]), float(bounds[1]) + clampf((game_point.y - 20.0) / 280.0, 0.0, 1.0) * float(bounds[3]))

func _world_scale() -> float:
	if not is_instance_valid(canvas):
		return 1.0
	return maxf(0.01, minf(canvas.size.x / 900.0, canvas.size.y / 350.0))

func _canvas_contains_world(local: Vector2) -> bool:
	if not is_instance_valid(canvas):
		return true
	var scale := _world_scale()
	var offset := (canvas.size - Vector2(900, 350) * scale) * 0.5
	return Rect2(offset, Vector2(900, 350) * scale).has_point(local)

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
	if not _canvas_contains_world(event.position):
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
		if pending_connection.is_empty():
			status_label.text = "Select a different room for the paired door."
			return
		var result := document.connect_rooms(str(pending_connection.room), pending_connection.point, inspected_room, point)
		if not result.ok:
			_show_edit_result(result)
			return
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
			document.set_source(source_editor.text)
			_show_edit_result(document.remove_walkable_region(inspected_room, geometry_region))
		return
	if geometry_mode == "erase": return
	if geometry_mode == "draw":
		document.set_source(source_editor.text)
		_show_edit_result(document.add_walkable_region(inspected_room, geometry_start, point))
	elif geometry_mode == "move" and geometry_region >= 0:
		document.set_source(source_editor.text)
		_show_edit_result(document.move_walkable_region(inspected_room, geometry_region, point - geometry_start))

func _show_edit_result(result: Dictionary) -> void:
	status_label.text = str(result.reason) + (". Resume validates the result." if result.ok else "")
	_refresh()

func _move_nearest_door(point: Vector2) -> void:
	_show_edit_result(document.move_nearest_door(inspected_room, point))

func _remove_nearest_door(point: Vector2) -> void:
	_show_edit_result(document.remove_nearest_door(inspected_room, point))

func _place_interaction(point: Vector2) -> void:
	_show_edit_result(document.place_interaction(inspected_room, point, "delay_guest" if interaction_effect_edit.selected == 1 else "close_valve", interaction_label_edit.text, int(interaction_duration_edit.value), int(interaction_effect_ticks_edit.value)))

func _place_actor(point: Vector2) -> void:
	_show_edit_result(document.place_actor(actor_id_edit.text, inspected_room, point, actor_sprite_edit.get_item_text(actor_sprite_edit.selected)))

func _place_commitment(point: Vector2) -> void:
	_show_edit_result(document.schedule_commitment(commitment_id_edit.text, actor_id_edit.text, int(schedule_timeline.value), inspected_room, point, float(commitment_speed_edit.value)))
	_show_schedule_warning(actor_id_edit.text.strip_edges())

func _move_commitment_on_timeline(commitment_id: String, at_tick: int) -> void:
	if not session.paused or commitment_id.is_empty(): return
	var result := document.retime_commitment(commitment_id, at_tick)
	_show_edit_result(result)
	if result.ok:
		for commitment in document.content.commitments:
			if commitment.id == commitment_id:
				_show_schedule_warning(str(commitment.actor))
				break

func _show_schedule_warning(actor_id: String) -> void:
	for warning in Content.schedule_warnings(document.candidate()):
		if actor_id.is_empty() or warning.actor == actor_id:
			status_label.text = str(warning.message)
			return

func _save_storylet() -> void:
	if not session.paused or rewinding:
		status_label.text = "Pause before authoring a storylet."
		return
	var flags := {}
	if storylet_flag_edit.selected > 0: flags.close_valve = storylet_flag_edit.selected == 1
	var result := document.save_storylet(storylet_id_edit.text, scene_id_edit.text, inspected_room, Array(required_actor_edit.text.split(",")), int(storylet_start_edit.value), int(storylet_end_edit.value), flags)
	if not result.ok:
		_show_edit_result(result)
		return
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
	if not session.paused or rewinding: return
	document.set_source(source_editor.text)
	var result := document.import_background(inspected_room, name, bytes)
	if not result.ok:
		status_label.text = str(result.reason)
		return
	background_textures.erase(result.id)
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
